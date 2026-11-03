# My Cloud Café

A Flutter café management game for browsers and mobile, with local saves and optional Supabase account sync. No ads, payments, premium currency or paid unlocks.

## Play

Prepare a customer's order, wait for brewing, then serve it to earn coins and XP. Spend earned coins on equipment, recipes and furniture. Recruit Ayu to automate service and generate capped earnings while away. Talk to customers and claim one-time café milestones.

- 8 recipes, 5 equipment types, 4 furniture types and 3 room palettes.
- Isometric café drawn in Flutter; no original game's artwork, audio or code is bundled.
- Responsive desktop navigation and mobile bottom navigation.
- Local autosave, previous-save recovery and copy/paste backups.
- Optional email/password accounts with per-user saves, optimistic cloud revisions and explicit conflict resolution.
- Offline web reload after the first complete installation; all rendering assets and fonts are served locally.
- Android/iOS project scaffolds included. Web is the verified delivery target; native builds require their platform SDKs.

## Run

Use Flutter **3.47.9** / Dart **3.13.7**.

```sh
flutter pub get
flutter run -d chrome
```

Cloud accounts are optional. To enable them, pass only the project's public URL and publishable (or legacy anon) key:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

Never embed a service-role key. Local play does not require an account. Clearing browser storage removes local progress; export a backup or sync first.

## Build and verify

```sh
flutter analyze
flutter test
bash tools/build_web.sh
python3 -m http.server 8080 --directory build/web
```

The build script accepts `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables, pins the Flutter SDK, bundles CanvasKit locally, and generates the offline cache. Serve `build/web` over HTTPS in production (localhost is suitable for development).

See [verification](docs/VERIFICATION.md), [deployment](docs/DEPLOYMENT.md) and [reverse-engineering evidence](docs/REVERSE_ENGINEERING.md).

## Reconstruction boundary

The requested reference is [My Cafe — Restaurant Game](https://play.google.com/store/apps/details?id=com.melesta.coffeeshop). This implementation reconstructs documented game concepts with new code, content and balancing. It is not a recovered or modified original app.

[REA 6.8.0](https://github.com/morluto/rea) was installed and its Android readiness was checked. Binary analysis requires a locally supplied APK and a verified JADX engine. No APK was supplied for this implementation; original formulas, assets, story graphs and network protocols remain unverified. A reproducible REA investigation runner is included in `tools/rea/`.

## Data

Supabase migrations are in `supabase/migrations/`. Every game-owned table uses the `mcc_` prefix. `mcc_cafe_saves` stores one JSON game save per authenticated user, protected by row-level security. A security-invoker RPC performs revision-checked saves, rejecting stale writes from another device. Offline changes remain queued locally until a connection succeeds. Conflicts are resolved by the player rather than merging currency or applying silent last-write-wins.

Guest and signed-in progress use separate local storage slots. Signing out returns to the guest game. Game state is client-authoritative for this single-player game; it must not be reused as a trusted competitive score or monetary balance.
