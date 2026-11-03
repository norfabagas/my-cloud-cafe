#!/usr/bin/env python3
"""Capture REA evidence for a supplied APK. Never launches or modifies the APK."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

REA_VERSION = "6.8.0"
EXPECTED_PACKAGE = "com.melesta.coffeeshop"
JADX_SHA256 = "6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command_prefix():
    # A local executable path is one argument; never interpolate it into a shell.
    executable = os.environ.get("REA_BIN")
    return [executable] if executable else ["npx", "--yes", f"rea-agents@{REA_VERSION}"]


def run(prefix, arguments, output, name, working_directory, timeout=300, allowed_codes=(0,)):
    stdout_path = output / f"{name}.json"
    stderr_path = output / f"{name}.stderr.log"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        result = subprocess.run(
            prefix + arguments,
            stdout=stdout,
            stderr=stderr,
            cwd=working_directory,
            timeout=timeout,
            check=False,
        )
    if result.returncode not in allowed_codes:
        raise RuntimeError(f"REA {name} failed ({result.returncode}); see {stderr_path.name} and {stdout_path.name}")
    try:
        return json.loads(stdout_path.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise RuntimeError(f"REA {name} returned invalid JSON; retained unmodified output") from error


def readiness_projection(doctor):
    return {
        "rea_version": doctor.get("identity", {}).get("cli_package_version"),
        "ready": doctor.get("healthy") is True,
        "scope": doctor.get("scope"),
        "checks": [
            {key: check[key] for key in ("name", "ok", "classification", "detail", "remediation") if key in check}
            for check in doctor.get("scope_checks", [])
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("readiness", "inspect"))
    parser.add_argument("apk", nargs="?", type=Path)
    parser.add_argument("--output", required=True, type=Path, help="New directory; existing directories are never overwritten")
    args = parser.parse_args()
    apk = args.apk.resolve() if args.apk else None
    if args.mode == "inspect":
        if apk is None or not apk.is_file() or apk.suffix.lower() != ".apk":
            parser.error("inspect requires an existing standalone .apk file")
        try:
            with zipfile.ZipFile(apk) as archive:
                if "AndroidManifest.xml" not in archive.namelist():
                    parser.error("APK has no root AndroidManifest.xml; supply the base standalone APK, not an XAPK/APKM wrapper")
        except zipfile.BadZipFile:
            parser.error("APK is not a readable ZIP archive")
    elif apk is not None:
        parser.error("readiness does not accept an APK")
    output = args.output.resolve()
    try:
        output.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        parser.error("output already exists; use a new evidence directory")
    summary = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "rea_version": REA_VERSION,
        "target_package": EXPECTED_PACKAGE,
        "mode": args.mode,
        "status": "started",
        "runtime_observed": False,
    }
    original_digest = sha256(apk) if apk else None
    if apk:
        summary["artifact"] = {"filename": apk.name, "size_bytes": apk.stat().st_size, "sha256": original_digest}
    write_json(output / "summary.json", summary)
    exit_code = 0
    try:
        prefix = command_prefix()
        # npm package acquisition occurs outside the target project's directory.
        with tempfile.TemporaryDirectory(prefix="rea-investigation-") as working_directory:
            version = subprocess.run(prefix + ["--version"], cwd=working_directory, capture_output=True, text=True, timeout=180, check=True).stdout.strip()
            if version != REA_VERSION:
                raise RuntimeError(f"Expected REA {REA_VERSION}; selected executable reported {version!r}")
            if apk:
                # Built-in signature inspection needs no JADX. Preserve it even
                # when the separate code-analysis engine is unavailable.
                run(prefix, ["inspect-apk-signature", str(apk), "--json"], output, "apk-signature", working_directory)
            jar_path = os.environ.get("REA_JADX_MCP_JAR")
            if jar_path:
                jar = Path(jar_path)
                if not jar.is_file() or sha256(jar) != JADX_SHA256:
                    raise RuntimeError("REA_JADX_MCP_JAR must point to the official 0.7.1 JAR matching REA's pinned SHA-256; refusing a different engine")
            # Doctor returns 1 for a valid diagnostic report that is not healthy.
            doctor = run(prefix, ["doctor", "--provider", "jadx", "--json"], output, "doctor-raw", working_directory, allowed_codes=(0, 1))
            readiness = readiness_projection(doctor)
            write_json(output / "readiness.json", readiness)
            if not readiness["ready"]:
                raise RuntimeError("JADX is not ready. Supply JDK 17+ and the verified jadx-headless-mcp 0.7.1 JAR through REA_JADX_MCP_JAR. See readiness.json.")
            if apk:
                package = run(prefix, ["inspect-android-package", str(apk), "--json"], output, "android-package", working_directory)
                observed = package.get("normalized_result", {}).get("package_name")
                summary["observed_package"] = observed
                if observed != EXPECTED_PACKAGE:
                    raise RuntimeError(f"Package identity is {observed!r}, expected {EXPECTED_PACKAGE!r}; evidence retained, do not attribute it to My Cafe")
            summary["status"] = "static_inventory_complete" if apk else "readiness_complete"
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        summary["status"] = "blocked_or_failed"
        summary["error"] = str(error)
        exit_code = 1
    finally:
        if apk:
            current_digest = sha256(apk) if apk.is_file() else None
            summary["artifact_unchanged"] = current_digest == original_digest
            if not summary["artifact_unchanged"]:
                summary["status"] = "artifact_changed"
                summary["error"] = "APK bytes changed during analysis; discard any cross-file conclusions"
                exit_code = 1
        write_json(output / "summary.json", summary)
    print(f"{summary['status']}: {output}")
    if "error" in summary:
        print(summary["error"], file=sys.stderr)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
