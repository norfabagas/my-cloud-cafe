# Verification — 3 November 2026

## Passed locally

- Flutter 3.47.9 / Dart 3.13.7 release web build.
- `flutter analyze`: no issues.
- 19 Flutter tests covering economy rewards, recipe gates, offline limits, automated service, save validation, recovery, account namespaces, pending changes, revision acknowledgements, HTTP identity binding, outage retries, conflicts and responsive layouts.
- Responsive views at 360, 768, 1024 and 1440 pixels, including a 600-pixel-tall desktop viewport.
- Browser smoke test in Chrome headless: prepare and serve an order, persist it, open the mobile account page, disconnect the network and reload successfully. No JavaScript errors, failed HTTP resources or external font/renderer requests.
- Offline bundle: about 12.2 MB before HTTP compression, with one cross-browser CanvasKit runtime and local fonts. Alternate renderers and debug symbols are excluded.

Run browser verification after building with Playwright available and an installed Chromium executable:

```sh
CHROME_PATH=/path/to/chrome-headless-shell node tools/qa/browser_smoke.cjs
```

The smoke test serves the actual release locally, uses a fresh browser context, and writes temporary evidence under ignored `build/qa/`.

## Supabase

The existing `niceblue` project was selected after the account's two-project free limit prevented a dedicated project. Only game-specific database objects were added.

Live database checks confirmed `mcc_cafe_saves` has RLS enabled, `anon` cannot read it, and authenticated users have the required table privileges. SELECT/INSERT/UPDATE policies compare `auth.uid()` with `owner_id`, including UPDATE's WITH CHECK. The revision-checked RPC is SECURITY INVOKER and accepts `p_state` and `p_expected_revision`.

The `prefix_mcc_tables` migration renamed the existing game table to `mcc_cafe_saves` and updated the RPC without rebuilding the table. A live transaction verified inserts, revision conflicts, owner isolation, owner reassignment rejection and anonymous access denial, then rolled back its test rows.

The client captures and explicitly binds each HTTP request's bearer token to its initiating account. A real SDK request against a local HTTP dependency proved that switching the active account during a write does not change the request identity. A second local HTTP scenario exercised unavailable reads, pending local saves, successful retries and explicit conflict resolution. These transport tests use controlled responses from the implemented RPC contract; they do not validate email delivery or a real user's login credentials.

No test signup email was sent. Existing shared-project Auth settings were preserved. Signup asks the player to confirm email and then return to the game to log in.

## Outstanding boundaries

- The original game APK was not supplied; REA readiness and the reproducible investigation runner are provided, but no original binary analysis is claimed.
- Android and iOS scaffolds exist; native builds and device testing require their platform SDKs and were not run here.
- The Netlify project and public Supabase build variables are prepared. Production is not published yet: the connected Netlify operations lack upload and Git-link capabilities, and the normal API is not authenticated. Linking the repository through a browser requires the user's approval for that fallback.
