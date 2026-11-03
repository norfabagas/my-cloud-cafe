#!/usr/bin/env python3
"""Create a content-versioned, same-origin-only offline shell after Flutter builds."""
import hashlib
import json
import sys
from pathlib import Path


def generate(root: Path) -> dict:
    if not (root / 'main.dart.js').is_file() or not (root / 'index.html').is_file():
        raise SystemExit('Expected a completed Flutter JavaScript web release.')
    # Bootstrap explicitly selects the cross-browser full CanvasKit renderer.
    # Keep its two runtime files; alternate engines/debug symbols add ~30 MiB.
    bootstrap = (root / 'flutter_bootstrap.js').read_text()
    if "canvasKitVariant: 'full'" in bootstrap:
        renderer = root / 'canvaskit'
        keep = {renderer / 'canvaskit.js', renderer / 'canvaskit.wasm'}
        if not all(path.is_file() for path in keep):
            raise SystemExit('Pinned CanvasKit runtime is incomplete.')
        for path in renderer.rglob('*'):
            if path.is_file() and path not in keep:
                path.unlink()
    excluded = {'service-worker.js', 'cafe-assets.json', 'flutter_service_worker.js'}
    entries = []
    version_hash = hashlib.sha256()
    for path in sorted(root.rglob('*')):
        if not path.is_file() or path.name in excluded or path.suffix == '.map':
            continue
        relative = path.relative_to(root).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        version_hash.update(f'{relative}\0{digest}\n'.encode())
        entries.append({'url': '/' + relative, 'sha256': digest, 'bytes': path.stat().st_size})
    version = version_hash.hexdigest()[:20]
    manifest = {'version': version, 'assets': entries}
    (root / 'cafe-assets.json').write_text(json.dumps(manifest, indent=2) + '\n')
    urls = ['/', *[entry['url'] for entry in entries], '/cafe-assets.json']
    worker = r"""'use strict';
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
"""
    worker = worker.replace('__VERSION__', json.dumps(version)).replace('__ASSETS__', json.dumps(urls))
    (root / 'service-worker.js').write_text(worker)
    # The custom worker is the sole cache owner. Do not ship Flutter's retired worker.
    (root / 'flutter_service_worker.js').unlink(missing_ok=True)
    return {'version': version, 'count': len(entries), 'bytes': sum(e['bytes'] for e in entries)}


if __name__ == '__main__':
    print(json.dumps(generate(Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web'))))
