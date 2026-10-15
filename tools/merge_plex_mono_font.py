# Gộp 3 file IBM Plex Mono woff2 (latin / latin-ext / vietnamese, bản tách theo unicode-range của Võ Lâm Idle) thành 1 TTF.
# Tách file thì chữ có dấu bị HarfBuzz rã thành chữ gốc + dấu nằm ở 2 font khác nhau → dấu lệch. Cần: pip install fonttools brotli
# Chạy: python tools/merge_plex_mono_font.py <thư mục chứa woff2> assets/fonts/ibm_plex_mono/IBMPlexMono-Regular-vi.ttf
import sys
from fontTools.ttLib import TTFont
from fontTools.merge import Merger, Options
src = sys.argv[1]; out = sys.argv[2]
names = ["latin", "latin-ext", "vietnamese"]
paths = []
for n in names:
    f = TTFont(f"{src}/ibm-plex-mono-400-{n}.woff2")
    print(n, "glyf" in f, len(f.getGlyphOrder()), len(f.getBestCmap()), f["head"].unitsPerEm)
    f.flavor = None
    p = f"part-{n}.ttf"; f.save(p); paths.append(p)
merged = Merger(options=Options(drop_tables=["vhea","vmtx"])).merge(paths)
merged.save(out)
m = TTFont(out); cm = m.getBestCmap()
print("merged glyphs", len(m.getGlyphOrder()), "cmap", len(cm), "has U+1ED3", 0x1ED3 in cm, "has U+00F4", 0xF4 in cm, "U+0300", 0x300 in cm)
