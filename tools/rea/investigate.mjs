#!/usr/bin/env node
/**
 * Capture REA evidence for a supplied APK using Node.js.
 * Mirrors tools/rea/investigate.py exactly.
 * Never launches or modifies the APK.
 */

import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';

const REA_VERSION = '6.8.0';
const EXPECTED_PACKAGE = 'com.melesta.coffeeshop';
const JADX_SHA256 = '6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75';

function writeJson(filePath, value) {
  writeFileSync(filePath, JSON.stringify(value, null, 2) + '\n', 'utf-8');
}

function sha256(filePath) {
  const hash = createHash('sha256');
  const buffer = readFileSync(filePath);
  hash.update(buffer);
  return hash.digest('hex');
}

function commandPrefix() {
  const executable = process.env.REA_BIN;
  if (executable) {
    return [executable];
  }
  return ['npx', '--yes', `rea-agents@${REA_VERSION}`];
}

function run(prefix, args, outputDir, name, cwd, timeoutMs = 300000, allowedCodes = [0]) {
  const stdoutPath = path.join(outputDir, `${name}.json`);
  const stderrPath = path.join(outputDir, `${name}.stderr.log`);

  const [cmd, ...cmdArgs] = [...prefix, ...args];
  const isWindows = process.platform === 'win32';
  const execCmd = isWindows && (cmd === 'npx' || cmd === 'npm') ? `${cmd}.cmd` : cmd;

  const result = spawnSync(execCmd, cmdArgs, {
    cwd,
    timeout: timeoutMs,
    shell: isWindows,
    encoding: 'utf-8',
    maxBuffer: 50 * 1024 * 1024,
  });

  writeFileSync(stdoutPath, result.stdout || '', 'utf-8');
  writeFileSync(stderrPath, result.stderr || '', 'utf-8');

  const code = result.status ?? 1;
  if (!allowedCodes.includes(code)) {
    throw new Error(`REA ${name} failed (${code}); see ${path.basename(stderrPath)} and ${path.basename(stdoutPath)}`);
  }

  try {
    return JSON.parse(result.stdout);
  } catch (err) {
    throw new Error(`REA ${name} returned invalid JSON; retained unmodified output`);
  }
}

function readinessProjection(doctor) {
  return {
    rea_version: doctor?.identity?.cli_package_version,
    ready: doctor?.healthy === true,
    scope: doctor?.scope,
    checks: (doctor?.scope_checks || []).map((check) => {
      const projected = {};
      for (const key of ['name', 'ok', 'classification', 'detail', 'remediation']) {
        if (key in check) {
          projected[key] = check[key];
        }
      }
      return projected;
    }),
  };
}

function main() {
  const args = process.argv.slice(2);
  let mode = null;
  let apkPath = null;
  let outputDir = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--output' && i + 1 < args.length) {
      outputDir = resolve(args[++i]);
    } else if (!mode && (args[i] === 'readiness' || args[i] === 'inspect')) {
      mode = args[i];
    } else if (!apkPath) {
      apkPath = resolve(args[i]);
    }
  }

  if (!mode || !outputDir) {
    console.error('Usage: node investigate.mjs <readiness|inspect> [apkPath] --output <outputDir>');
    process.exit(1);
  }

  if (mode === 'inspect') {
    if (!apkPath || !existsSync(apkPath) || !apkPath.toLowerCase().endsWith('.apk')) {
      console.error('inspect requires an existing standalone .apk file');
      process.exit(1);
    }
  } else if (apkPath) {
    console.error('readiness does not accept an APK');
    process.exit(1);
  }

  if (existsSync(outputDir)) {
    console.error('output already exists; use a new evidence directory');
    process.exit(1);
  }

  mkdirSync(outputDir, { recursive: true });

  const summary = {
    created_at: new Date().toISOString(),
    rea_version: REA_VERSION,
    target_package: EXPECTED_PACKAGE,
    mode,
    status: 'started',
    runtime_observed: false,
  };

  const originalDigest = apkPath ? sha256(apkPath) : null;
  if (apkPath) {
    summary.artifact = {
      filename: basename(apkPath),
      size_bytes: statSync(apkPath).size,
      sha256: originalDigest,
    };
  }

  writeJson(path.join(outputDir, 'summary.json'), summary);
  let exitCode = 0;

  try {
    const prefix = commandPrefix();
    const workingDir = os.tmpdir();

    const [vCmd, ...vArgs] = [...prefix, '--version'];
    const isWindows = process.platform === 'win32';
    const execCmd = isWindows && (vCmd === 'npx' || vCmd === 'npm') ? `${vCmd}.cmd` : vCmd;
    const vResult = spawnSync(execCmd, vArgs, { cwd: workingDir, encoding: 'utf-8', shell: isWindows });
    const version = (vResult.stdout || '').trim();
    if (version !== REA_VERSION) {
      throw new Error(`Expected REA ${REA_VERSION}; selected executable reported '${version}'`);
    }

    if (apkPath) {
      run(prefix, ['inspect-apk-signature', apkPath, '--json'], outputDir, 'apk-signature', workingDir);
    }

    const jarPath = process.env.REA_JADX_MCP_JAR;
    if (jarPath) {
      if (!existsSync(jarPath) || sha256(jarPath) !== JADX_SHA256) {
        throw new Error("REA_JADX_MCP_JAR must point to the official 0.7.1 JAR matching REA's pinned SHA-256; refusing a different engine");
      }
    }

    const doctor = run(prefix, ['doctor', '--provider', 'jadx', '--json'], outputDir, 'doctor-raw', workingDir, 300000, [0, 1]);
    const readiness = readinessProjection(doctor);
    writeJson(path.join(outputDir, 'readiness.json'), readiness);

    const jadxCheck = readiness.checks.find((c) => c.name === 'jadx');
    const jadxReady = jadxCheck ? jadxCheck.ok === true : readiness.ready;
    if (!jadxReady) {
      throw new Error('JADX is not ready. Supply JDK 17+ and the verified jadx-headless-mcp 0.7.1 JAR through REA_JADX_MCP_JAR. See readiness.json.');
    }

    if (apkPath) {
      const pkg = run(prefix, ['inspect-android-package', apkPath, '--json'], outputDir, 'android-package', workingDir);
      const observed = pkg?.normalized_result?.package_name;
      summary.observed_package = observed;
      if (observed !== EXPECTED_PACKAGE) {
        throw new Error(`Package identity is '${observed}', expected '${EXPECTED_PACKAGE}'; evidence retained, do not attribute it to My Cafe`);
      }
    }

    summary.status = apkPath ? 'static_inventory_complete' : 'readiness_complete';
  } catch (error) {
    summary.status = 'blocked_or_failed';
    summary.error = error.message;
    exitCode = 1;
  } finally {
    if (apkPath) {
      const currentDigest = existsSync(apkPath) ? sha256(apkPath) : null;
      summary.artifact_unchanged = currentDigest === originalDigest;
      if (!summary.artifact_unchanged) {
        summary.status = 'artifact_changed';
        summary.error = 'APK bytes changed during analysis; discard any cross-file conclusions';
        exitCode = 1;
      }
    }
    writeJson(path.join(outputDir, 'summary.json'), summary);
  }

  console.log(`${summary.status}: ${outputDir}`);
  if (summary.error) {
    console.error(summary.error);
  }
  process.exit(exitCode);
}

main();
