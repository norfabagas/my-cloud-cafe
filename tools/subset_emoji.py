#!/usr/bin/env python3
"""Subset the official Noto Color Emoji font to this game's local glyphs.

Usage: python3 tools/subset_emoji.py /path/to/official/NotoColorEmoji.ttf
Requires fonttools. The output is a modified font renamed Cafe Emoji.
"""
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

source = Path(sys.argv[1])
output = Path(__file__).resolve().parents[1] / 'assets/fonts/CafeEmoji.ttf'
font = TTFont(source)
options = subset.Options()
options.name_IDs = ['*']
options.name_languages = ['*']
options.recalc_timestamp = False
subsetter = subset.Subsetter(options=options)
subsetter.populate(text='☕🍵🥐🍫🍰🍨🪑🌿💡📚👩\u200d🍳\ufe0f')
subsetter.subset(font)
for record in font['name'].names:
    if record.nameID in (1, 3, 4, 6, 16, 17):
        names = {1: 'Cafe Emoji', 3: 'CafeEmoji-Subset-1', 4: 'Cafe Emoji', 6: 'CafeEmoji', 16: 'Cafe Emoji', 17: 'Regular'}
        record.string = names[record.nameID].encode(record.getEncoding())
font.save(output)
check = TTFont(output)
cmap = check.getBestCmap()
required = {ord(c) for c in '☕🍵🥐🍫🍰🍨🪑🌿💡📚👩🍳'}
assert required <= set(cmap)
print(f'Validated {output.name}: {output.stat().st_size} bytes; {len(cmap)} encoded glyphs')
