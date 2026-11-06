# My Cloud Café

A Flutter café management game for browsers and mobile. Google login through the existing Supabase project is required; saves stay scoped to each account. No ads, payments, premium currency or paid unlocks.

## Play

Sign in with Google to open the café. Customers walk in, take a seat, order, and leave after service or when their patience runs out. Select a customer, tap each required tool in sequence, wait for its ingredient, then serve. A latte needs espresso followed by milk. Recipes take 5–12 seconds of active preparation, all below 30 seconds.

- 8 manageable recipes, 6 equipment types, 6 furniture types and 3 room palettes.
- Isometric café drawn in Flutter; no original game's artwork, audio or code is bundled.
- The café is the only activity screen. Menu, shop, staff, customer book, stories, and accounts open in-game popups.
- Frame-driven walking and brewing effects, independent of simulation ticks and saves. Pinch to zoom and pan without rotating the camera.
- Hold and drag furniture or tools in layout mode; coordinate dialogs are also available. Tools require a free bar slot or table. Chairs must adjoin tables, and paths to chairs stay open.
- Up to 3 staff with barista, server, or combined duties. Staff use the same recipe steps and shared tools as the player; rest restores their energy.
- 24 named recurring customers with persistent appearances and visit counts. New identities save locally immediately and register in the owner-scoped database on account sync.
- Local autosave, previous-save recovery and copy/paste backups.
- Mandatory Google login using the project's existing provider, with session restore, expiry handling, per-user saves, optimistic cloud revisions and explicit conflict resolution. Logout closes the café and its dialogs.
- Offline web reload after the first complete installation; all rendering assets and fonts are served locally.
- Android/iOS project scaffolds included. Web is the verified delivery target; native builds require their platform SDKs.

## Run

Use Flutter **3.47.7** / Dart **3.13.5**.

```sh
flutter pub get
flutter run -d chrome --web-hostname=localhost --web-port=3030 --dart-define-from-file=.env.local.json
```

Default local origin: **http://localhost:3030**. Copy `.env.example` to the ignored `.env.local.json` and fill the existing project's public key. The VS Code launch profile uses the same port. On Windows, `./tools/run_web.ps1` starts the web server on 3030 (`-Release` selects release mode).

Pass the existing project's public URL and publishable (or legacy anon) key. Add `http://localhost:3030` and the production origin to Supabase Auth's Redirect URLs. Google is already enabled on the configured project; email/password is disabled.

```sh
flutter run -d chrome --web-hostname=localhost --web-port=3030 \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

Never embed a service-role key. Missing configuration, anonymous sessions and expired sessions keep the café locked. Offline play requires a previously signed-in, unexpired session. Clearing browser storage removes local progress; export a backup or sync first.

## Build and verify

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

The build script accepts `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables, bundles CanvasKit locally, and generates the offline cache. Serve `build/web` over HTTPS in production (localhost is suitable for development).

See [verification](docs/VERIFICATION.md), [deployment](docs/DEPLOYMENT.md) and [reverse-engineering evidence](docs/REVERSE_ENGINEERING.md).

## Reconstruction boundary

The requested reference is [My Cafe — Restaurant Game](https://play.google.com/store/apps/details?id=com.melesta.coffeeshop). This implementation reconstructs documented game concepts with new code, content and balancing. It is not a recovered or modified original app.

[REA 6.8.0](https://github.com/morluto/rea) was run against the supplied standalone APK (`My+Cafe+—+Restaurant+Game_2026.11.1.0_APKPure.apk`, SHA-256: `c5c278adbfe4e0be97ec504e4560ce953a44c3a3ac7f0fe402845452b563b2e8`) using JDK 21 and the verified `jadx-headless-mcp` 0.7.1 JAR. Complete static inventory evidence is recorded under `evidence/my-cafe-001/`. As established by the class inspection, core simulation formulas and runtime mechanics reside within the compiled native engine library (`libgame_shared.so`); proprietary binaries and assets remain unbundled. A reproducible REA investigation runner is included in `tools/rea/`.

## Data

Supabase migrations are in `supabase/migrations/`. Every game-owned table uses the `mcc_` prefix. `mcc_cafe_saves` stores one JSON game save per authenticated user, protected by row-level security. A security-invoker RPC performs revision-checked saves, rejecting stale writes from another device. Offline changes remain queued locally until a connection succeeds. Conflicts are resolved by the player rather than merging currency or applying silent last-write-wins.

Account progress uses separate local storage slots. Legacy guest data is retained separately, but guest play is no longer accessible. Signing out returns to the Google login screen. Game state is client-authoritative for this single-player game; it must not be reused as a trusted competitive score or monetary balance.
