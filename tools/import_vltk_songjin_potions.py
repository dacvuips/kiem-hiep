"""Lấy ẢNH + DỮ LIỆU thuốc chiến trường Tống Kim từ VLTK gốc -> assets/items/icons/ + data/items/songjin_potions.json.

    python -X utf8 -I tools/import_vltk_songjin_potions.py

Nguồn đã đối chiếu (server Anh Việt, settings/item/magicscript.txt + potion.txt, script/item/battles/sj_*.lua,
script/skill/battles/*.lua) với bài cẩm nang VNG "Chiến trường Tống Kim":
- Thuốc tăng lực: script gọi AddSkillState(skill, cấp, 1, 3240) -> 3240 frame / 18 = 180 giây (3 phút).
  Giá trị = cấp × 10 (sj_physicsdamage/sj_manadamage/sj_state_enhance), riêng Trường Mệnh = cấp × 100 (sj_status_max).
- Chiến Cổ / Lệnh Bài / Kháng Đơn Chi Giác: CastSkill(491/492/510, 1) — hào quang vùng quanh người dùng, cấp 1.
- Càn Khôn Tạo Hóa Đan: ModifyAttrib(153/154, giá trị, 100) = hồi sinh lực/nội lực mỗi nửa giây trong 100 frame.
Tất cả chỉ dùng được trong bản đồ Tống Kim (checkSJMaps).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import vltk_source  # noqa: E402
import spr_to_png  # noqa: E402
from import_vltk_item_icons import OUT_DIR, SMALL_DIR, icon_name, make_small  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(PROJECT, "data", "items", "songjin_potions.json")

POTION15 = "\\spr\\item\\medecine\\obj-potion15.spr"
BUFF_FRAMES = 3240  ## 3 phút

## id = (genre, detail) gốc. effects: [thuộc tính magic gốc, giá trị, số frame]. points = giá điểm tích lũy (bài VNG),
## money = giá lượng. aura = tác dụng lên đồng đội (team) hoặc kẻ địch (enemy) xung quanh.
POTIONS = [
    {"id": "6_155", "name": "Chiến Cổ", "image": "\\spr\\item\\songjin\\wardrum.spr", "points": 3000, "stack": 50,
     "aura": "team", "skill_id": 491,
     "effects": [["lifemax_p", 30, BUFF_FRAMES], ["allres_p", 30, BUFF_FRAMES]],
     "desc": "Trong 3 phút, bản thân và đồng đội xung quanh tăng 30% sinh lực tối đa và 30% kháng tất cả."},
    {"id": "6_156", "name": "Lệnh Bài", "image": "\\spr\\item\\songjin\\token.spr", "points": 2000, "stack": 50,
     "aura": "team", "skill_id": 492,
     "effects": [["fastwalkrun_p", 30, BUFF_FRAMES], ["attackspeed_v", 50, BUFF_FRAMES], ["castspeed_v", 50, BUFF_FRAMES]],
     "desc": "Trong 3 phút, bản thân và đồng đội xung quanh tăng 30% tốc độ di chuyển, 50% tốc độ đánh và xuất chiêu."},
    {"id": "6_213", "name": "Kháng Đơn Chi Giác", "image": "\\spr\\item\\songjin\\clarion.spr", "points": 3000, "stack": 50,
     "aura": "enemy", "skill_id": 510,
     "effects": [["meleedamagereturn_p", -20, BUFF_FRAMES], ["rangedamagereturn_p", -20, BUFF_FRAMES]],
     "desc": "Trong 3 phút, kẻ địch xung quanh bị giảm 20% phản đòn cận chiến và tầm xa (bài VNG gọi là \"Chống phản đòn\")."},
    {"id": "6_177", "name": "Ngoại Phổ Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 487,
     "effects": [["addphysicsdamage_p", 50, BUFF_FRAMES]], "desc": "Trong 3 phút, sát thương vật lý ngoại công tăng 50%."},
    {"id": "6_178", "name": "Ngoại Độc Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 485,
     "effects": [["addpoisondamage_v", 50, BUFF_FRAMES]], "desc": "Trong 3 phút, độc sát ngoại công tăng 50 điểm."},
    {"id": "6_179", "name": "Ngoại Băng Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 486,
     "effects": [["addcolddamage_v", 100, BUFF_FRAMES]], "desc": "Trong 3 phút, băng sát ngoại công tăng 100 điểm."},
    {"id": "6_180", "name": "Nội Phổ Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 479,
     "effects": [["addphysicsmagic_v", 100, BUFF_FRAMES]], "desc": "Trong 3 phút, sát thương vật lý nội công tăng 100 điểm."},
    {"id": "6_181", "name": "Nội Độc Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 480,
     "effects": [["addpoisonmagic_v", 50, BUFF_FRAMES]], "desc": "Trong 3 phút, độc sát nội công tăng 50 điểm."},
    {"id": "6_182", "name": "Nội Băng Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 481,
     "effects": [["addcoldmagic_v", 100, BUFF_FRAMES]], "desc": "Trong 3 phút, băng sát nội công tăng 100 điểm."},
    {"id": "6_183", "name": "Nội Hỏa Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 482,
     "effects": [["addfiremagic_v", 100, BUFF_FRAMES]], "desc": "Trong 3 phút, hỏa sát nội công tăng 100 điểm."},
    {"id": "6_184", "name": "Nội Lôi Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 483,
     "effects": [["addlightingmagic_v", 100, BUFF_FRAMES]], "desc": "Trong 3 phút, lôi sát nội công tăng 100 điểm."},
    {"id": "6_185", "name": "Trường Mệnh Hoàn", "image": POTION15, "points": 300, "stack": 50, "skill_id": 488,
     "effects": [["lifemax_v", 500, BUFF_FRAMES]], "desc": "Trong 3 phút, sinh lực tối đa tăng 500 điểm."},
    {"id": "6_186", "name": "Gia Tốc Hoàn", "image": POTION15, "points": 300, "stack": 50, "skill_id": 493,
     "effects": [["fastwalkrun_p", 20, BUFF_FRAMES]],
     "desc": "Trong 3 phút, tốc độ di chuyển tăng 20% (bản gốc tên \"Gia Bào hoàn\")."},
    {"id": "6_187", "name": "Cao Thiểm Hoàn", "image": POTION15, "points": 300, "stack": 50, "skill_id": 494,
     "effects": [["adddefense_v", 500, BUFF_FRAMES]], "desc": "Trong 3 phút, né tránh tăng 500 điểm."},
    {"id": "6_188", "name": "Cao Trung Hoàn", "image": POTION15, "points": 300, "stack": 50, "skill_id": 495,
     "effects": [["attackratingenhance_v", 500, BUFF_FRAMES]], "desc": "Trong 3 phút, chính xác tăng 500 điểm."},
    {"id": "6_189", "name": "Phi Tốc Hoàn", "image": POTION15, "points": 600, "stack": 50, "skill_id": 496,
     "effects": [["attackspeed_v", 50, BUFF_FRAMES], ["castspeed_v", 50, BUFF_FRAMES]],
     "desc": "Trong 3 phút, tốc độ đánh và xuất chiêu tăng 50%."},
    ## Đan hồi phục mua bằng ngân lượng — mất khi rớt mạng / thoát game / hết trận.
    {"id": "6_215", "name": "Càn Khôn Tạo Hóa Đan (trung)", "image": "\\spr\\item\\medecine\\obj-potion13.spr",
     "money": 6000, "stack": 10, "effects": [["lifereplenish_v", 1000, 100], ["manareplenish_v", 1000, 100]],
     "desc": "Mỗi nửa giây hồi 1000 sinh lực và 1000 nội lực, trong khoảng 5 giây."},
    {"id": "6_216", "name": "Càn Khôn Tạo Hóa Đan (tiểu)", "image": "\\spr\\item\\medecine\\obj-potion13.spr",
     "money": 3000, "stack": 10, "effects": [["lifereplenish_v", 500, 100], ["manareplenish_v", 500, 100]],
     "desc": "Mỗi nửa giây hồi 500 sinh lực và 500 nội lực, trong khoảng 5 giây."},
    {"id": "1_0_cuuchuyen", "name": "Cửu Chuyển Hoàn Hồn Đan", "image": "\\spr\\item\\medecine\\obj-potion03.spr",
     "money": 2000, "stack": 1, "effects": [["lifereplenish_v", 500, 100]],
     "desc": "Mỗi nửa giây hồi 500 sinh lực, trong khoảng 5 giây."},
    {"id": "1_1_odau", "name": "Ô Đầu Hoàn Thần Đan", "image": "\\spr\\item\\medecine\\obj-potion08.spr",
     "money": 2000, "stack": 1, "effects": [["manareplenish_v", 500, 100]],
     "desc": "Mỗi nửa giây hồi 500 nội lực, trong khoảng 5 giây."},
]


def main():
    paks = vltk_source.paks()
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SMALL_DIR, exist_ok=True)
    tmp = os.path.join(OUT_DIR, "_tmp.spr")
    done = {}
    for p in POTIONS:
        path = p["image"]
        name = icon_name(path)
        p["icon"] = name
        p["songjin_only"] = True
        if path in done:
            continue
        out = os.path.join(OUT_DIR, name + ".png")
        data = paks.read(path)
        if data is None:
            print("THIẾU", path)
            done[path] = False
            continue
        open(tmp, "wb").write(data)
        images, _meta = spr_to_png.read_spr(tmp)
        frame = images[0]
        box = frame.getbbox()
        if box:
            frame = frame.crop(box)
        frame.save(out, optimize=True)
        make_small(out, os.path.join(SMALL_DIR, name + ".png"))
        print("ảnh", name, frame.size, "(%d frame)" % len(images))
        done[path] = True
    if os.path.isfile(tmp):
        os.remove(tmp)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(POTIONS, f, ensure_ascii=False, indent=1)
    print("ghi", OUT_JSON, len(POTIONS), "món")


if __name__ == "__main__":
    main()
