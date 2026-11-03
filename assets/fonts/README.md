# Local fonts

- `Roboto-Regular.ttf`, `Roboto-Bold.ttf`: copied unchanged from the Flutter 3.47.9 Material font bundle. Apache 2.0 license in `Roboto_LICENSE.txt`.
- `CafeEmoji.ttf`: modified subset of Google's Noto Color Emoji, renamed **Cafe Emoji**. SIL Open Font License 1.1 in `NOTO_EMOJI_LICENSE.txt`.

Official emoji source: https://github.com/googlefonts/noto-emoji/blob/main/2D/fonts/NotoColorEmoji.ttf

The subset covers the exact game symbols: ☕ 🍵 🥐 🍫 🍰 🍨 🪑 🌿 💡 📚 👩‍🍳, including U+FE0F and U+200D sequences. Its glyph closure includes the woman-cook ligature. Recreate it with `python3 tools/subset_emoji.py /path/to/NotoColorEmoji.ttf` (requires fonttools).

These fonts are bundled so gameplay never needs a remote font service. The UI uses the `CafeSans` and `CafeEmoji` families declared in `pubspec.yaml`.
