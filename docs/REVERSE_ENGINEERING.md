# Reconstruction evidence

## Current boundary

The reference target is [My Cafe — Restaurant Game on Google Play](https://play.google.com/store/apps/details?id=com.melesta.coffeeshop&hl=id), package `com.melesta.coffeeshop`.

On 2026-11-04, the standalone APK `My+Cafe+—+Restaurant+Game_2026.11.1.0_APKPure.apk` (SHA-256: `c5c278adbfe4e0be97ec504e4560ce953a44c3a3ac7f0fe402845452b563b2e8`, 91,909,776 bytes) was inspected using **REA 6.8.0** (`rea-agents@6.8.0`) with JDK 21 and the pinned `jadx-headless-mcp-0.7.1-all.jar`. All evidence and diagnostic logs are recorded under [evidence/my-cafe-001/](../evidence/my-cafe-001/).

Key findings from REA static inspection:
- **Status**: `static_inventory_complete` (recorded in [summary.json](../evidence/my-cafe-001/summary.json), `artifact_unchanged: true`).
- **APK Signing**: Verified self-consistent APK Signature Scheme v2 (Evidence ID `ev_944ea5783218c4b4c8fcdc180376d537fbff080e054d46b51cae6da9d7b6ced2`). Signer: `O=Melesta`, Serial `4E11BD11`, Certificate SHA-256 fingerprint: `2088e47f48c48c25dc91691a71296ad87daf3c4853649f3f3e2e48dff792038d`.
- **Package Inventory**: Target `com.melesta.coffeeshop`, Version Name `2026.11.1.0` (code `100836`), Min SDK 26, Target SDK 36. Total parsed class count: **24,763 classes** across 6 DEX files (Evidence ID `ev_40ddd1d120f4555d3a6d08f5d34e18f8742db9607278a2c932e114ae16c3e3fb`, [android-package.json](../evidence/my-cafe-001/android-package.json)).
- **Class Architecture**: Top-level Melesta classes mapped (Evidence ID `ev_631eb673ce4cdcc51d561bc6c60665db3d543dd17588e5be9fdd3148b54c6776`, [melesta-classes.json](../evidence/my-cafe-001/melesta-classes.json)):
  - Core app & engine bootstrap: `com.melesta.coffeeshop.CoffeeShopApplication`, `com.melesta.mge.MGEApplication`, `com.melesta.mge.MGEGameActivity`.
  - Native engine thunks: `com.melesta.mge.MGEJNIHelper` binding the UI to `libgame_shared.so` (40.25 MiB native C++ engine) and `libunitycoherencenative.so`.
  - Expansion / OBB downloader: `com.melesta.obb.ObbDownloaderService`, `com.melesta.mge.exp.ExpansionsManager`.
  - Monetization & storage: `com.melesta.payment.PaymentManager`, `com.melesta.thirdpartylibs.DatabaseHelper`, `com.melesta.thirdpartylibs.Cipher`.
- **Reconstruction Note**: Because gameplay simulations and formulas are encapsulated inside native compiled code (`libgame_shared.so`), the clean-room Flutter game in this repository implements its own balanced progression, offline saves, recipes, and UI without reusing proprietary binaries or assets.

## Feature ledger

| Question | Evidence | Status / implementation direction |
| --- | --- | --- |
| Manage a cafe, menu and staff? | Official Play listing & APK components | Publicly described; implement local cafe progression, recipes, orders and staff. |
| Place furniture and choose decor? | Official Play listing & APK components | Publicly described; implement an original editable cafe layout. |
| Customer conversations and choices? | Official Play listing & APK components | Publicly described; use original characters and dialogue. |
| Original game offline? | APK manifest requires `android.permission.INTERNET` and OBB downloader | New requirement; design local state persistence and offline startup after the first complete web load. |
| Original monetization? | APK declares `com.android.vending.BILLING` and `com.melesta.payment.PaymentManager` | New game has no billing, ads, premium currency purchases or payment gates. Earned game coins fund progression. |
| Exact recipes, prices, timings, balancing and server logic? | Encapsulated in native `libgame_shared.so` | Independent design choice in Flutter implementation. |
| Original visual assets, proprietary code and story? | Melesta proprietary assets | Not reused. |
| Original online festivals and social systems? | Native network components | Requires a separate product decision; no claims of offline reproduction of remote services. |

The public Play description was read through web lookup; it is not a substitute for app execution. The [REA repository](https://github.com/morluto/rea), inspected through the GitHub connector, documents static APK inspection using headless JADX and a JDK.

## Resume with an APK

Run [the supplied investigation script](../tools/rea/README.md) with the original standalone APK and verified prerequisites. It records byte identity, signing declarations and package inventory. Then trace only the subsystems needed to answer unresolved questions: order lifecycle, recipe prerequisites, staff effects, save format, layout rules, and progression. Record each conclusion against returned Evidence IDs and exact source locations. Keep static observations, runtime observations and new design choices separate.

A native game engine, downloaded data, or backend may hold mechanics beyond JADX's class inventory. Only the evidence actually obtained can close those gaps. Removing purchases in this project means omitting billing from the new implementation; it does not modify the original game or claim access to its paid entitlements.
