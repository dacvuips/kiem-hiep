"""Trích ảnh thanh trạng thái trên cùng (UiHeaderControlBar.ini gốc) từ pak -> assets/ui/topbar/*.png."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vltk_pak import PakList
import spr_to_png
from import_vltk_avatar import CLIENT

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "topbar")
FILES = {"panel": "新血条面板", "life": "生命条", "mana": "内力条", "stamina": "体力条", "exp": "经验条"}

def main():
    paks = PakList(CLIENT)
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_tmp.spr")
    for key, name in FILES.items():
        data = paks.read("spr/ui3/主界面/%s.spr" % name)
        if data is None:
            print("THIẾU", key)
            continue
        open(tmp, "wb").write(data)
        images, meta = spr_to_png.read_spr(tmp)
        images[0].save(os.path.join(OUT, key + ".png"))
        print(key, len(images), images[0].size)
    try:
        os.remove(tmp)
    except OSError:
        pass

main()
