# Reconstruction evidence

## Current boundary

The supplied target is [My Cafe — Restaurant Game on Google Play](https://play.google.com/store/apps/details?id=com.melesta.coffeeshop&hl=id), package `com.melesta.coffeeshop`. No APK, extracted package, game source, device, or runtime capture was supplied. **The original binary has not been reverse engineered.** The Flutter implementation is an independent gameplay reconstruction from public feature descriptions, with new code and visuals.

REA 6.8.0 was installed and its Android CLI schemas and scoped readiness were checked on 2026-11-03. The actual `doctor --provider jadx --json` result reports a compatible Node runtime and a missing JADX JAR. The scoped, sanitized record is in [evidence/rea-readiness.json](evidence/rea-readiness.json). Readiness is not evidence about the target game.

## Feature ledger

| Question | Evidence | Status / implementation direction |
| --- | --- | --- |
| Manage a cafe, menu and staff? | Official Play listing, “PLAY A REALISTIC CAFE SIMULATOR” | Publicly described; implement local cafe progression, recipes, orders and staff. |
| Place furniture and choose decor? | Official Play listing, “STYLE YOUR CAFE WITH DECOR” | Publicly described; implement an original editable cafe layout. |
| Customer conversations and choices? | Official Play listing, “DISCOVER INTERACTIVE CAFE GAME STORYLINES” | Publicly described; use original characters and dialogue. |
| Original game offline? | Official Play listing says internet is required | New requirement; design local state persistence and offline startup after the first complete web load. |
| Original monetization? | Play listing labels ads and in-app purchases | New game has no billing, ads, premium currency purchases or payment gates. Earned game coins fund progression. |
| Exact recipes, prices, timings, balancing and server logic? | No binary or runtime evidence | Unknown. New game values are design choices, not recovered constants. |
| Original visual assets, proprietary code and story? | Not supplied or extracted | Not reused. |
| Original online festivals and social systems? | Public listing mentions social competitions and festivals | Requires a separate product decision; no claims of offline reproduction of remote services. |

The public Play description was read through web lookup; it is not a substitute for app execution. The [REA repository](https://github.com/morluto/rea), inspected through the GitHub connector, documents static APK inspection using headless JADX and a JDK.

## Resume with an APK

Run [the supplied investigation script](../tools/rea/README.md) with the original standalone APK and verified prerequisites. It records byte identity, signing declarations and package inventory. Then trace only the subsystems needed to answer unresolved questions: order lifecycle, recipe prerequisites, staff effects, save format, layout rules, and progression. Record each conclusion against returned Evidence IDs and exact source locations. Keep static observations, runtime observations and new design choices separate.

A native game engine, downloaded data, or backend may hold mechanics beyond JADX's class inventory. Only the evidence actually obtained can close those gaps. Removing purchases in this project means omitting billing from the new implementation; it does not modify the original game or claim access to its paid entitlements.
