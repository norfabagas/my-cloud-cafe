# Verification — 6 November 2026

## Passed locally

- Flutter 3.47.7 / Dart 3.13.5 release web build.
- `flutter analyze`: no issues.
- 37 Flutter tests covering economy rewards, ingredient sequencing, tool contention, staff roles/rest and manual handoff, menu availability, visitor identity, legacy saves, table-supported tools, recovery, account isolation, HTTP identity binding, cloud conflicts, pinch zoom without rotation, dragging after zoom, paths and popup layouts. Auth cases include Google OAuth URL/launch handling, denied play before a session, failed launch, anonymous/expired sessions, restored account caches, token renewal, logout popup removal, missing configuration and phone/desktop login layouts.
- Responsive views at 360, 768, 1024 and 1440 pixels, including a 600-pixel-tall desktop viewport.
- Offline bundle generated with CanvasKit runtime and local fonts. Alternate renderers and debug symbols excluded.
- REA 6.8.0 static analysis with OpenJDK 21 and headless JADX 0.7.1: `static_inventory_complete` across all 24,763 Dalvik classes in `evidence/my-cafe-001/`.

Run browser verification after building with Playwright available and an installed Chromium executable:

```sh
CHROME_PATH=/path/to/chrome-headless-shell node tools/qa/browser_smoke.cjs
```

The smoke test serves the actual release locally, uses a fresh browser context, and writes temporary evidence under ignored `build/qa/`.

The release browser run passed desktop espresso service, mobile account popup, offline reload with preserved progress, a seeded two-ingredient latte, rejected milk-before-espresso, no premature serving, and hiring exactly three staff. Animated scene screenshots changed between samples. No JavaScript errors, failed HTTP resources, or external font/renderer requests occurred. Browser frame callbacks over 90 samples had a median interval of 8.3 ms, p95 16.7 ms, and no interval above 50 ms on this machine. This measures browser frame scheduling, not a guarantee for other devices or GPU render time.

## Customer registry

`mcc_customers` registers fictional customers from accepted cloud snapshots using a SECURITY INVOKER trigger. Registration and revision checking share a transaction; a rejected stale save cannot mutate customer rows. Guests keep their registry locally. Signed-in changes are saved locally and queued for the existing periodic cloud sync.

`tools/qa/customer_registry.cjs` passed on PGlite 0.5.15 (Postgres) and is included in CI. It checks initial registration, revisit upsert, stale-save atomicity, cross-account reads/writes, owner reassignment and anonymous denial. Run it with `PGLITE_MODULE` pointing to an installed `@electric-sql/pglite` module.

The additive registry migration was applied to the existing project. `supabase/verify_customer_registry.sql` passed against the live database and rolled back every test write. RLS, explicit grants, ownership predicates and the save trigger were checked. The shared project's pre-existing advisors include unrelated application objects and platform settings; this change does not modify those objects.

## Supabase

The existing `niceblue` project was selected after the account's two-project free limit prevented a dedicated project. Only game-specific database objects were added.

Live database checks confirmed `mcc_cafe_saves` has RLS enabled, `anon` cannot read it, and authenticated users have the required table privileges. SELECT/INSERT/UPDATE policies compare `auth.uid()` with `owner_id`, including UPDATE's WITH CHECK. The revision-checked RPC is SECURITY INVOKER and accepts `p_state` and `p_expected_revision`.

The `prefix_mcc_tables` migration renamed the existing game table to `mcc_cafe_saves` and updated the RPC without rebuilding the table. A live transaction verified inserts, revision conflicts, owner isolation, owner reassignment rejection and anonymous access denial, then rolled back its test rows.

The client captures and explicitly binds each HTTP request's bearer token to its initiating account. A real SDK request against a local HTTP dependency proved that switching the active account during a write does not change the request identity. A second local HTTP scenario exercised unavailable reads, pending local saves, successful retries and explicit conflict resolution. These transport tests use controlled responses from the implemented RPC contract; they do not validate email delivery or a real user's login credentials.

No test signup email was sent. Existing shared-project Auth settings were preserved; the login-required update uses its active Google provider.

## Mandatory Google login

The public Auth settings endpoint confirms Google enabled and email/password disabled on the existing `dhkgygjsuamelcfnwvlg` project; aggregate identities also use Google. The application reuses that provider and does not offer an inactive password form. It mounts the café only for a non-anonymous, unexpired session with the matching account cache, and disposes the account Navigator and its dialogs on logout/expiry. Legacy guest saves are retained but cannot open the game.

The release browser Auth fixture passed OAuth navigation, PKCE code-verifier exchange, cancellation without unlocking the café, session persistence, logout with popup removal, and the gameplay/offline checks. It intercepts only the existing Supabase origin. Fictional sessions never reach the hosted database. These controlled tests do not claim a completed real Google account login.

The live authorization endpoint and its newly generated PKCE flow confirmed the production origin was not initially in Redirect URLs: the recorded referrer fell back to `http://localhost:3000`. Adding `https://my-cloud-cafe.netlify.app` to the existing allowlist is required before publishing this login-required build. The Supabase plugin has no Auth configuration write tool, the CLI has no access token, and Windows Computer Use rejected URL verification; the exact dashboard change was requested from the project owner.

## Outstanding boundaries

- The standalone original APK was supplied and static inventory completed with REA 6.8.0 ([evidence/my-cafe-001/](../evidence/my-cafe-001/)). Core game simulation logic was identified in native `libgame_shared.so` and remains clean-room reconstructed.
- Android and iOS scaffolds exist; native builds and device testing require their platform SDKs and were not run here.
- Production is hosted at https://my-cloud-cafe.netlify.app through the authenticated Netlify CLI. The connected plugin verifies deployment status. Native touch performance and Android/iOS device builds remain untested; Flutter touch gestures are covered by widget tests and web behavior by Chromium.
