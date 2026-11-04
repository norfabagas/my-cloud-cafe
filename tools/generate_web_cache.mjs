#!/usr/bin/env node
/**
 * Create a content-versioned, same-origin-only offline shell after Flutter builds.
 * Node.js equivalent of tools/generate_web_cache.py.
 */

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, unlinkSync, readdirSync, statSync } from 'node:fs';
import { resolve, join, relative, extname, basename } from 'node:path';

function getFilesRecursively(dir) {
  let results = [];
  if (!existsSync(dir)) return results;
  const list = readdirSync(dir);
  for (const file of list) {
    const filePath = join(dir, file);
    const stat = statSync(filePath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getFilesRecursively(filePath));
    } else {
      results.push(filePath);
    }
  }
  return results;
}

function generate(rootPath) {
  const root = resolve(rootPath);
  const mainDartJs = join(root, 'main.dart.js');
  const indexHtml = join(root, 'index.html');

  if (!existsSync(mainDartJs) || !existsSync(indexHtml)) {
    throw new Error('Expected a completed Flutter JavaScript web release.');
  }

  const bootstrapPath = join(root, 'flutter_bootstrap.js');
  if (existsSync(bootstrapPath)) {
    const bootstrap = readFileSync(bootstrapPath, 'utf-8');
    if (bootstrap.includes("canvasKitVariant: 'full'")) {
      const renderer = join(root, 'canvaskit');
      const keep = new Set([join(renderer, 'canvaskit.js'), join(renderer, 'canvaskit.wasm')]);
      const ckFiles = getFilesRecursively(renderer);
      for (const p of ckFiles) {
        if (!keep.has(p)) {
          try { unlinkSync(p); } catch {}
        }
      }
    }
  }

  const excluded = new Set(['service-worker.js', 'cafe-assets.json', 'flutter_service_worker.js', '.last_build_id']);
  const allFiles = getFilesRecursively(root).sort();
  const entries = [];
  const versionHash = createHash('sha256');

  for (const filePath of allFiles) {
    const fileName = basename(filePath);
    if (excluded.has(fileName) || extname(filePath) === '.map') {
      continue;
    }
    const rel = relative(root, filePath).replace(/\\/g, '/');
    const content = readFileSync(filePath);
    const digest = createHash('sha256').update(content).digest('hex');
    versionHash.update(`${rel}\0${digest}\n`);
    entries.push({
      url: '/' + rel,
      sha256: digest,
      bytes: statSync(filePath).size,
    });
  }

  const version = versionHash.digest('hex').slice(0, 20);
  const manifest = { version, assets: entries };
  writeFileSync(join(root, 'cafe-assets.json'), JSON.stringify(manifest, null, 2) + '\n', 'utf-8');

  const urls = ['/', ...entries.map((e) => e.url), '/cafe-assets.json'];
  const workerTemplate = `'use strict';
const PREFIX = 'my-cloud-cafe-';
const CACHE = PREFIX + __VERSION__;
const ASSETS = __ASSETS__;
const KNOWN = new Set(ASSETS);
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      await cache.addAll(ASSETS.map(path => new Request(path, {cache: 'reload'})));
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
    // New versions wait for existing game tabs to close, avoiding interrupted play.
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith(PREFIX) && name !== CACHE).map(name => caches.delete(name)));
    await self.clients.claim();
    const clients = await self.clients.matchAll({type: 'window'});
    for (const client of clients) client.postMessage({type: 'CAFE_OFFLINE_READY', version: CACHE});
  })());
});
self.addEventListener('message', event => {
  if (event.data?.type === 'CAFE_CACHE_STATUS') {
    event.waitUntil(caches.has(CACHE).then(ready => {
      event.source?.postMessage({type: ready ? 'CAFE_OFFLINE_READY' : 'CAFE_OFFLINE_PENDING', version: CACHE});
    }));
  }
});
self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  // Supabase/auth requests are cross-origin and never enter this cache.
  if (request.mode === 'navigate') {
    event.respondWith(caches.open(CACHE).then(cache => cache.match('/index.html')).then(cached => cached || fetch(request)));
    return;
  }
  if (!KNOWN.has(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(url.pathname);
    return cached || fetch(request);
  })());
});
`;

  const worker = workerTemplate
    .replace('__VERSION__', JSON.stringify(version))
    .replace('__ASSETS__', JSON.stringify(urls));

  writeFileSync(join(root, 'service-worker.js'), worker, 'utf-8');

  const retiredWorker = join(root, 'flutter_service_worker.js');
  if (existsSync(retiredWorker)) {
    try { unlinkSync(retiredWorker); } catch {}
  }

  return {
    version,
    count: entries.length,
    bytes: entries.reduce((sum, e) => sum + e.bytes, 0),
  };
}

const targetDir = process.argv[2] || 'build/web';
const result = generate(targetDir);
console.log(JSON.stringify(result, null, 2));
