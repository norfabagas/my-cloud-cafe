# Web build and Netlify

The app targets Flutter **3.47.9**, pinned to commit `c197ca5199e9ee5661e865596c9c07294dfab51c`.

```bash
export FLUTTER_ROOT=/path/to/flutter
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-publishable-or-legacy-anon-key
bash tools/build_web.sh
python3 -m http.server 8080 --directory build/web
```

Omit both Supabase variables for a guest-only build. These are **public client configuration**; never supply a service-role or secret key. The build rejects those key types. Supabase RLS controls user access.

`tools/build_web.sh` installs the pinned SDK if one is not supplied, enforces the committed package lockfile, builds release JavaScript with local CanvasKit, then generates `service-worker.js` and its SHA-256 asset manifest. Keep `.cache/`, `.netlify/`, generated builds, and private local configuration out of Git.

## Offline behavior

- First launch requires HTTPS and internet (localhost is allowed during development).
- The **“Siap dimainkan offline”** notice appears only after every bundled asset has been cached successfully.
- The cache includes the game, renderer, icons, and bundled fonts. Supabase requests and user credentials are never cached by the service worker.
- On a failed or partial download, the new worker does not activate; the last complete cache is retained.
- A new game version becomes active after existing game tabs are closed. This avoids interrupting a session or mixing renderer versions.
- Clearing browser site data removes local saves and the offline shell. Copy a backup or sync the account first.

## Netlify project

- Project: `my-cloud-cafe`
- Team: `norfabagas`
- Site ID: `c7588442-6a71-4e91-a66d-931e27818b3b`
- Dashboard: https://app.netlify.com/projects/my-cloud-cafe
- Production origin: https://my-cloud-cafe.netlify.app

The project is published through an authenticated manual CLI deployment. `.netlify/` is ignored and contains the local project link.

For continuous deployment, connect `norfabagas/my-cloud-cafe`, use branch `main`, and keep the root `netlify.toml` build settings. The public `SUPABASE_URL` and `SUPABASE_ANON_KEY` variables are already configured on this Netlify project. Leave secret scanning enabled; these two values are public, so only exempt the precise public variable if a scanner produces a false positive.

For an authorized manual deployment with a configured CLI session:

```bash
netlify deploy --prod --dir=build/web --site=c7588442-6a71-4e91-a66d-931e27818b3b
```

The GitHub workflow runs analysis and tests and uploads the same web artifact. It does not pretend to deploy when no Netlify credential or Git connection has been configured.

## Customer registry migration

Apply `20261106123041_cafe_customer_registry.sql` before publishing the simulation update. It adds only `mcc_customers`, its owner-scoped policies, and a SECURITY INVOKER trigger on accepted `mcc_cafe_saves` writes. The migration has been applied to the configured project, and `supabase/verify_customer_registry.sql` passed with all test writes rolled back. Guest customers remain local; signed-in customer registration follows periodic cloud sync, including retries after an outage.

Existing saves migrate their embedded chairs, customer identities, tools and pending recipes when loaded by the updated client. Close all existing café tabs and reopen the site to activate a waiting offline update.
