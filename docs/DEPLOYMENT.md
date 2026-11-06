# Web build and Netlify

The app targets Flutter **3.47.9**, pinned to commit `c197ca5199e9ee5661e865596c9c07294dfab51c`.

```bash
export FLUTTER_ROOT=/path/to/flutter
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-publishable-or-legacy-anon-key
bash tools/build_web.sh
python3 -m http.server 8080 --directory build/web
```

Both Supabase variables are required for usable login. They are **public client configuration**; never supply a service-role or secret key. The build rejects those key types. A build without them displays login unavailable and keeps the game closed. Supabase RLS controls database access.

`tools/build_web.sh` installs the pinned SDK if one is not supplied, enforces the committed package lockfile, builds release JavaScript with local CanvasKit, then generates `service-worker.js` and its SHA-256 asset manifest. Keep `.cache/`, `.netlify/`, generated builds, and private local configuration out of Git.

## Offline behavior

- First launch requires HTTPS and internet (localhost is allowed during development).
- Google login is required before play. A cached account can play offline while its access token remains unexpired; once expired, access stays closed until the session refreshes or the player signs in online.
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

Apply `20261106123041_cafe_customer_registry.sql` before publishing the simulation update. It adds only `mcc_customers`, its owner-scoped policies, and a SECURITY INVOKER trigger on accepted `mcc_cafe_saves` writes. The migration has been applied to the configured project, and `supabase/verify_customer_registry.sql` passed with all test writes rolled back. Customer registration follows periodic cloud sync, including retries after an outage.

Existing saves migrate their embedded chairs, customer identities, tools and pending recipes when loaded by the updated client. Close all existing café tabs and reopen the site to activate a waiting offline update.

## Required Google login

The configured project `dhkgygjsuamelcfnwvlg` already enables Google. Reuse that provider and its OAuth client. No new project, API key, password provider, or database migration is needed.

In Authentication → URL Configuration → Redirect URLs, add `https://my-cloud-cafe.netlify.app`. Keep existing entries and the shared project's Site URL. The app requests its own origin as `redirectTo`, and Supabase Flutter handles the PKCE callback and persisted session. For local development, use a fixed web port and allow that local origin separately.

Before release, verify the production origin is accepted by the hosted authorization endpoint. At the initial inspection on 6 November, the requested cafe redirect was not allowlisted and the server selected `http://localhost:3000`; the required origin addition was requested from the project owner. Do not publish the mandatory-login build until the callback is verified.

The café and its nested Navigator mount only after a non-anonymous, unexpired session and matching account cache are ready. Logout, expiry or account change removes the game's popup routes and cancels its simulation timers. Missing Auth configuration never falls back to guest play. Existing guest saves remain stored separately and are not automatically assigned to a signed-in account.
