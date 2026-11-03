#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true TAR_OPTIONS=--no-same-owner
sdk_version=3.47.9
sdk_revision=c197ca5199e9ee5661e865596c9c07294dfab51c
if [[ -n "${FLUTTER_ROOT:-}" ]]; then
  flutter_bin="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  sdk_path="${NETLIFY_BUILD_BASE:-$PWD}/.cache/flutter-sdk-$sdk_version"
  if [[ ! -d "$sdk_path/.git" ]]; then
    mkdir -p "$(dirname "$sdk_path")"
    git clone --depth 1 --branch "$sdk_version" https://github.com/flutter/flutter.git "$sdk_path"
  fi
  actual_revision="$(git -C "$sdk_path" rev-parse HEAD)"
  if [[ "$actual_revision" != "$sdk_revision" ]]; then
    echo 'Flutter SDK checkout does not match the pinned release.' >&2
    exit 1
  fi
  flutter_bin="$sdk_path/bin/flutter"
fi
actual_version="$("$flutter_bin" --version --machine | python3 -c 'import sys,json; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "$actual_version" != "$sdk_version" ]]; then
  echo "Expected Flutter $sdk_version; received $actual_version." >&2
  exit 1
fi
public_config="$(mktemp)"
trap 'rm -f "$public_config"' EXIT
python3 - "$public_config" <<'PY'
import base64,json,os,sys,urllib.parse
url=os.environ.get('SUPABASE_URL','')
key=os.environ.get('SUPABASE_ANON_KEY','')
if bool(url)!=bool(key): raise SystemExit('Provide both SUPABASE_URL and SUPABASE_ANON_KEY, or neither for guest-only mode.')
if url:
 parsed=urllib.parse.urlparse(url)
 if parsed.scheme!='https' or not parsed.hostname or not parsed.hostname.endswith('.supabase.co'):
  raise SystemExit('SUPABASE_URL must be the HTTPS project API URL.')
 if key.startswith('sb_secret_'): raise SystemExit('Secret keys must never enter a web build.')
 if key.count('.')==2:
  try:
   payload=json.loads(base64.urlsafe_b64decode(key.split('.')[1]+'==='))
  except Exception: raise SystemExit('Invalid legacy Supabase key.')
  if payload.get('role')!='anon': raise SystemExit('Only an anon key is allowed in the frontend.')
 elif not key.startswith('sb_publishable_'):
  raise SystemExit('Expected a publishable or legacy anon key.')
with open(sys.argv[1],'w') as f: json.dump({'SUPABASE_URL':url,'SUPABASE_ANON_KEY':key},f)
PY
"$flutter_bin" pub get --enforce-lockfile
"$flutter_bin" build web --release --pwa-strategy=none --no-web-resources-cdn --dart-define-from-file="$public_config"
python3 tools/generate_web_cache.py build/web
