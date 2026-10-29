import json
import re
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

# -------------------------------------------------------------
# 1. Update data/skill_fx/anims.json
# -------------------------------------------------------------
anims_path = ROOT / "data" / "skill_fx" / "anims.json"
with open(anims_path, "r", encoding="utf-8") as f:
    anims = json.load(f)

element_meta = {
    "tien_giai_kim": ROOT / "assets" / "skill_fx" / "tien_giai_kim.json",
    "tien_giai_moc": ROOT / "assets" / "skill_fx" / "tien_giai_moc.json",
    "tien_giai_thuy": ROOT / "assets" / "skill_fx" / "tien_giai_thuy.json",
    "tien_giai_hoa": ROOT / "assets" / "skill_fx" / "tien_giai_hoa.json",
    "tien_giai_tho": ROOT / "assets" / "skill_fx" / "tien_giai_tho.json",
}

for k, meta_file in element_meta.items():
    if meta_file.exists():
        with open(meta_file, "r", encoding="utf-8") as f:
            m = json.load(f)
        anims[k] = {
            "additive": True,
            "cols": m.get("frames", 20),
            "dirs": m.get("directions", 1),
            "frames": m.get("frames", 20),
            "interval": m.get("interval", 40),
            "offset": [-m["center"][0], -m["center"][1]] if "center" in m else [-64, -120],
            "size": [m.get("frame_width", 130), m.get("frame_height", 140)]
        }
        print(f"Added anim {k}: {anims[k]}")

with open(anims_path, "w", encoding="utf-8") as f:
    json.dump(anims, f, ensure_ascii=False, indent=2)
print("Updated anims.json!")

# -------------------------------------------------------------
# 2. Update data/skill_fx/skills.json
# -------------------------------------------------------------
skills_fx_path = ROOT / "data" / "skill_fx" / "skills.json"
with open(skills_fx_path, "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

SKILL_180_DEFS = {
    "1220": {"name": "Kim Quyền La Hán", "precast": "tien_giai_kim", "series": 0, "child": 1230},
    "1221": {"name": "Chinh Chiến Bát Phương", "precast": "tien_giai_kim", "series": 0, "child": 1231},
    "1222": {"name": "Sâm La Độc Hải", "precast": "tien_giai_moc", "series": 1, "child": 1232},
    "1223": {"name": "Hấp Tinh Trận", "precast": "tien_giai_moc", "series": 1, "child": 1233},
    "1224": {"name": "Ba La Tâm Kinh", "precast": "tien_giai_thuy", "series": 2, "child": 1234},
    "1225": {"name": "Huyền Băng Vô Tắc", "precast": "tien_giai_thuy", "series": 2, "child": 1235},
    "1226": {"name": "Liệt Hỏa Phần Thiên", "precast": "tien_giai_hoa", "series": 3, "child": 1236},
    "1227": {"name": "Ô Y Quyết", "precast": "tien_giai_hoa", "series": 3, "child": 1237},
    "1228": {"name": "Chân Võ Thất Tiết", "precast": "tien_giai_tho", "series": 4, "child": 1238},
    "1229": {"name": "Thiên Cương Khí Kính", "precast": "tien_giai_tho", "series": 4, "child": 1239},
    "1230": {"name": "Minh Kính Vô Di", "precast": "tien_giai_kim", "series": 0, "child": 0},
    "1231": {"name": "Du Long Chân Khí", "precast": "tien_giai_kim", "series": 0, "child": 0},
    "1232": {"name": "Hồn Ảnh Tùng Sanh", "precast": "tien_giai_moc", "series": 1, "child": 0},
    "1233": {"name": "Hóa Giải Sát Thương", "precast": "tien_giai_moc", "series": 1, "child": 0},
    "1234": {"name": "Từ Hàng Phổ Độ", "precast": "tien_giai_thuy", "series": 2, "child": 0},
    "1235": {"name": "Dung Tuyết Vô Tung", "precast": "tien_giai_thuy", "series": 2, "child": 0},
    "1236": {"name": "Ma Âm Phệ Phách", "precast": "tien_giai_hoa", "series": 3, "child": 0},
    "1237": {"name": "Thiên Hành Khí Công", "precast": "tien_giai_hoa", "series": 3, "child": 0},
    "1238": {"name": "Âm Dương Khí Quyết", "precast": "tien_giai_tho", "series": 4, "child": 0},
    "1239": {"name": "Tiên Thiên Cương Khí", "precast": "tien_giai_tho", "series": 4, "child": 0},
}

for sid, info in SKILL_180_DEFS.items():
    skills_fx[sid] = {
        "attack_radius": 0,
        "aura": 0,
        "base": 0,
        "by_missle": 0,
        "char_anim": 11,
        "child": info["child"],
        "child_level": -1,
        "child_num": 1 if info["child"] else 0,
        "collide_event": 0,
        "collide_skill": 0,
        "do_hurt": 0,
        "event_level": 0,
        "fly_event": 0,
        "fly_skill": 0,
        "fly_time": 0,
        "form": 7,
        "gen_data": 0,
        "gen_style": 0,
        "heel": 0,
        "levels": {},
        "max_shadow": 0,
        "melee": 0,
        "name": info["name"],
        "need_shadow": 0,
        "param1": 0,
        "param2": 0,
        "physical": 0,
        "precast": info["precast"],
        "series": info["series"],
        "start_event": 0,
        "start_skill": 0,
        "state": 0,
        "stop_when_move": 0,
        "style": 3,
        "target_ally": 0,
        "target_enemy": 0,
        "target_self": 1,
        "time_per_cast": 0,
        "use_ar": 0,
        "vanish_event": 0,
        "vanish_skill": 0,
        "wait": 0
    }

with open(skills_fx_path, "w", encoding="utf-8") as f:
    json.dump(skills_fx, f, ensure_ascii=False, indent=2)
print("Updated skills.json!")

# -------------------------------------------------------------
# 3. Update systems/sect/data/*.tres
# -------------------------------------------------------------
TRES_DIR = ROOT / "systems" / "sect" / "data"

SECT_180_DATA = {
    "thieu_lam.tres": {
        "skill_id": "thieu_lam_kim_quyen_la_han",
        "name": "Kim Quyền La Hán",
        "vltk_id": 1220,
        "element": 0,
        "desc": "Kỹ năng thất truyền của phái Thiếu Lâm, dùng nó thì vạn tà không nhập. Có thể phản đòn sát thương cận chiến và tầm xa khi bị công kích.",
        "stat_lines": [
            ("Phản đòn cận chiến", 10.0, 50.0, "%"),
            ("Phản đòn tầm xa", 10.0, 50.0, "%"),
            ("Thời gian duy trì", 10.0, 15.0, " giây"),
            ("Tỷ lệ kích hoạt phản kích", 3.0, 5.0, "%"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "meleedamagereturn_p": [ [1, 10, 0, 20, 50, 0, 21, 50, 0], [1, 180, 0, 20, 270, 0] ],
            "rangedamagereturn_p": [ [1, 10, 0, 20, 50, 0, 21, 50, 0], [1, 180, 0, 20, 270, 0] ],
            "autoreplyskill": [ [1, 314881, 0, 20, 314900, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "thien_vuong_bang.tres": {
        "skill_id": "thien_vuong_chinh_chien_bat_phuong",
        "name": "Chinh Chiến Bát Phương",
        "vltk_id": 1221,
        "element": 0,
        "desc": "Kỹ năng thất truyền của phái Thiên Vương, dùng nó thì ngàn quân phải tránh. Có thể xóa hiệu ứng bất thường và né tránh phi đạn.",
        "stat_lines": [
            ("Né tránh phi đạn", 20.0, 80.0, "%"),
            ("Bỏ qua trạng thái bất thường", 100.0, 100.0, "%"),
            ("Thời gian duy trì", 1.0, 3.0, " giây"),
            ("Tỷ lệ kích hoạt", 1.0, 3.0, "%"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "missle_missrate": [ [1, 80, 0, 20, 20, 0, 21, 20, 0] ],
            "ignorenegativestate_p": [ [1, 100, 0, 20, 100, 0], [1, 18, 0, 20, 54, 0] ],
            "autoreplyskill": [ [1, 315137, 0, 20, 315156, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "ngu_doc_giao.tres": {
        "skill_id": "ngu_doc_sam_la_doc_hai",
        "name": "Sâm La Độc Hải",
        "vltk_id": 1222,
        "element": 1,
        "desc": "Kỹ năng thất truyền của phái Ngũ Độc, dùng nó thì vạn vật sâm la. Tự động kích hoạt Hồn Ảnh Tùng Sanh làm mục tiêu trúng độc liên hồi.",
        "stat_lines": [
            ("Tỷ lệ kích hoạt Hồn Ảnh", 10.0, 30.0, "%"),
            ("Giãn cách kích hoạt", 1.0, 1.0, " giây"),
            ("Độc sát nội công", 50.0, 300.0, " điểm/lần"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "autoattackskill": [ [1, 315393, 0, 20, 315412, 0], [1, -1, 0, 20, -1, 0], [1, 4618, 0, 20, 4638, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "duong_mon.tres": {
        "skill_id": "duong_mon_hap_tinh_tran",
        "name": "Hấp Tinh Trận",
        "vltk_id": 1223,
        "element": 1,
        "desc": "Kỹ năng thất truyền của phái Đường Môn, khi sinh lực dưới 25% kích hoạt ngăn chặn 100% sát thương phải chịu.",
        "stat_lines": [
            ("Ngăn chặn sát thương", 100.0, 100.0, "%"),
            ("Thời gian duy trì", 2.0, 5.0, " giây"),
            ("Tỷ lệ kích hoạt cứu nguy", 5.0, 20.0, "%"),
            ("Giãn cách kích hoạt", 10.0, 10.0, " giây"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "block_rate": [ [1, 100, 0, 20, 100, 0], [1, 36, 0, 20, 90, 0] ],
            "autorescueskill": [ [1, 315649, 0, 20, 315668, 0], [1, -1, 0, 20, -1, 0], [1, 46085, 0, 20, 46100, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "nga_mi.tres": {
        "skill_id": "nga_mi_ba_la_tam_kinh",
        "name": "Ba La Tâm Kinh",
        "vltk_id": 1224,
        "element": 2,
        "desc": "Kỹ năng thất truyền của phái Nga Mi, dùng nó thì có thể trừ ma kháng tà, kích hoạt Từ Hàng Phổ Độ hồi sinh lực toàn diện cho bản thân và đồng đội.",
        "stat_lines": [
            ("Tỷ lệ thi triển Từ Hàng Phổ Độ", 10.0, 30.0, "%"),
            ("Giãn cách kích hoạt", 3.0, 3.0, " giây"),
            ("Hồi phục sinh lực", 300.0, 2000.0, " điểm"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "autoattackskill": [ [1, 315905, 0, 20, 315924, 0], [1, -1, 0, 20, -1, 0], [1, 13834, 0, 20, 13854, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "thuy_yen_mon.tres": {
        "skill_id": "thuy_yen_huyen_bang_vo_tac",
        "name": "Huyền Băng Vô Tắc",
        "vltk_id": 1225,
        "element": 2,
        "desc": "Kỹ năng thất truyền của phái Thúy Yên, ẩn thân vô tung vô ảnh, né tránh hiểm cảnh trong chớp mắt.",
        "stat_lines": [
            ("Tàng hình ẩn thân", 2.0, 5.0, " giây"),
            ("Tỷ lệ kích hoạt", 5.0, 10.0, "%"),
            ("Thời gian hồi chiêu", 20.0, 10.0, " giây"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "hide": [ [1, 2, 0, 20, 5, 0], [1, 36, 0, 20, 90, 0] ],
            "autoreplyskill": [ [1, 316161, 0, 20, 316180, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "thien_nhan_giao.tres": {
        "skill_id": "thien_nhan_liet_hoa_phan_thien",
        "name": "Liệt Hỏa Phần Thiên",
        "vltk_id": 1226,
        "element": 3,
        "desc": "Kỹ năng thất truyền của phái Thiên Nhẫn, ngọn lửa ma giáo thiêu rụi kẻ địch, tự động kích hoạt Ma Âm Phệ Phách làm đối thủ hoảng loạn.",
        "stat_lines": [
            ("Tỷ lệ kích hoạt Ma Âm", 1.0, 3.0, "%"),
            ("Hỏa sát phản kích", 100.0, 500.0, " điểm"),
            ("Giãn cách phản kích", 30.0, 20.0, " giây"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "autoreplyskill": [ [1, 316417, 0, 20, 316436, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "cai_bang.tres": {
        "skill_id": "cai_bang_o_y_quyet",
        "name": "Ô Y Quyết",
        "vltk_id": 1227,
        "element": 3,
        "desc": "Kỹ năng thất truyền của phái Cái Bang, nâng cao uy lực Hỗn Thiên Khí Công và bỏ qua kháng hỏa của đối phương.",
        "stat_lines": [
            ("Bỏ qua kháng hỏa đối thủ", 6.0, 20.0, "%"),
            ("Tăng tỷ lệ Hỗn Thiên Khí Công", 2.0, 20.0, "%"),
            ("Thời gian duy trì", 5.0, 15.0, " giây"),
            ("Tỷ lệ kích hoạt", 3.0, 10.0, "%"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "anti_fireres_yan_p": [ [1, 6, 0, 20, 20, 0], [1, 90, 0, 20, 270, 0] ],
            "enhance_714_auto": [ [1, 2, 0, 20, 20, 0], [1, 90, 0, 20, 270, 0] ],
            "autoreplyskill": [ [1, 316673, 0, 20, 316692, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "vo_dang.tres": {
        "skill_id": "vo_dang_chan_vo_that_tiet",
        "name": "Chân Võ Thất Tiết",
        "vltk_id": 1228,
        "element": 4,
        "desc": "Kỹ năng thất truyền của phái Võ Đang, dùng Thái Cực chuyển hóa sát thương gánh chịu thành nội lực bảo hộ bản thân.",
        "stat_lines": [
            ("Sát thương chuyển hóa thành nội lực", 50.0, 200.0, "%"),
            ("Thời gian duy trì", 5.0, 15.0, " giây"),
            ("Tỷ lệ kích hoạt", 3.0, 10.0, "%"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "damage2addmana_p": [ [1, 50, 0, 20, 200, 0], [1, 90, 0, 20, 270, 0] ],
            "autoreplyskill": [ [1, 316929, 0, 20, 316948, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    },
    "con_lon.tres": {
        "skill_id": "con_lon_thien_cuong_khi_kinh",
        "name": "Thiên Cương Khí Kính",
        "vltk_id": 1229,
        "element": 4,
        "desc": "Kỹ năng thất truyền của phái Côn Lôn, mượn lôi đình thiên cương bảo hộ cơ thể, nâng cao Lưỡng Nghi Chân Khí và giảm lôi phòng đối phương.",
        "stat_lines": [
            ("Bỏ qua kháng lôi đối thủ", 5.0, 15.0, "%"),
            ("Tăng tỷ lệ Lưỡng Nghi Chân Khí", 3.0, 15.0, "%"),
            ("Thời gian duy trì", 5.0, 15.0, " giây"),
            ("Tỷ lệ kích hoạt", 3.0, 5.0, "%"),
            ("Ngũ hành tương khắc", 20.0, 50.0, "%")
        ],
        "vltk_attribs": {
            "anti_lightingres_yan_p": [ [1, 5, 0, 20, 15, 0], [1, 90, 0, 20, 270, 0] ],
            "enhance_717_auto": [ [1, 3, 0, 20, 15, 0], [1, 90, 0, 20, 270, 0] ],
            "autoreplyskill": [ [1, 317185, 0, 20, 317204, 0] ],
            "seriesdamage_p": [ [1, 20, 0, 20, 50, 0] ]
        }
    }
}

def format_packed_array(arr):
    return "PackedFloat32Array(" + ", ".join(str(int(x)) if isinstance(x, (int, float)) and x == int(x) else str(x) for x in arr) + ")"

for tres_filename, data in SECT_180_DATA.items():
    tres_path = TRES_DIR / tres_filename
    if not tres_path.exists():
        print(f"Skipping {tres_filename}: not found")
        continue

    text = tres_path.read_text(encoding="utf-8")
    if data["skill_id"] in text:
        print(f"Skill {data['name']} already exists in {tres_filename}")
        continue

    # Find highest sub_resource integer ID
    sub_ids = [int(m) for m in re.findall(r'id="SubResource_(\d+)"', text)]
    max_sub = max(sub_ids) if sub_ids else 100

    stat_sub_ids = []
    new_sub_blocks = []

    # Generate StatLines sub_resources
    for label, v1, vmax, suffix in data["stat_lines"]:
        max_sub += 1
        sub_id = f"SubResource_{max_sub}"
        stat_sub_ids.append(sub_id)
        stat_block = f"""[sub_resource type="Resource" id="{sub_id}"]
script = ExtResource("3_statline")
label = "{label}"
value_at_level_1 = {v1}
value_at_max_level = {vmax}
suffix = "{suffix}"
"""
        new_sub_blocks.append(stat_block)

    # Generate SkillDefinition sub_resource
    max_sub += 1
    skill_sub_id = f"SubResource_{max_sub}"

    # Format vltk_attribs
    attribs_lines = []
    for attr_name, arrays in data["vltk_attribs"].items():
        arr_strs = [format_packed_array(a) for a in arrays]
        attribs_lines.append(f'"{attr_name}": [{", ".join(arr_strs)}]')
    attribs_str = "{\n" + ",\n".join(attribs_lines) + "\n}"

    stat_lines_refs = ", ".join(f'SubResource("{s}")' for s in stat_sub_ids)

    skill_block = f"""[sub_resource type="Resource" id="{skill_sub_id}"]
script = ExtResource("2_skill")
id = "{data['skill_id']}"
skill_name = "{data['name']}"
practice_only = true
max_level = 20
target_enemy = false
target_ally = false
target_self = true
is_aura = false
vltk_is_physical = 0
vltk_missle_form = 7
vltk_attack_radius = 0
vltk_state_special_id = 0
vltk_damage_range = 0
vltk_range_damage = 0
vltk_hit_friend = 0
vltk_attribs = {attribs_str}
req_level = 180
vltk_skill_id = {data['vltk_id']}
icon = ExtResource("vicon_{data['skill_id']}")
description = "{data['desc']}"
school_text = "Hỗ trợ chủ động (Thất truyền 180)"
is_active = true
category = 0
base_damage = 0.0
mana_cost = 0.0
cooldown = 20.0
range = 0.0
element = {data['element']}
damage_growth_per_level = 0.0
stat_lines = Array[ExtResource("3_statline")]([{stat_lines_refs}])
is_hotbar = true
"""
    new_sub_blocks.append(skill_block)

    # Add ext_resource for the icon
    ext_icon = f'[ext_resource type="Texture2D" path="res://assets/skill_icons/vltk/{data["skill_id"]}.png" id="vicon_{data["skill_id"]}"]\n'
    last_ext = list(re.finditer(r'^\[ext_resource [^\n]*\n', text, re.M))
    insert_ext_at = last_ext[-1].end() if last_ext else text.index("\n\n") + 1
    text = text[:insert_ext_at] + ext_icon + text[insert_ext_at:]

    # Append new sub_resources right before [resource]
    res_pos = text.rfind("\n[resource]")
    text = text[:res_pos] + "\n\n" + "\n".join(new_sub_blocks) + text[res_pos:]

    # Append skill_sub_id to skills array in [resource]
    # Match skills = Array[ExtResource("2_skill")]([...])
    skills_match = re.search(r'skills = Array\[ExtResource\("2_skill"\)\]\(\[([^\]]*)\]\)', text)
    if skills_match:
        current_skills = skills_match.group(1).strip()
        updated_skills = current_skills + f', SubResource("{skill_sub_id}")'
        text = text[:skills_match.start(1)] + updated_skills + text[skills_match.end(1):]
    else:
        print(f"Warning: could not find skills array in {tres_filename}")

    tres_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"Added Skill 180 '{data['name']}' to {tres_filename}!")

# -------------------------------------------------------------
# 4. Update data/items/misc_items.json (Bí Kíp 180 / Thất Truyền)
# -------------------------------------------------------------
items_path = ROOT / "data" / "items" / "misc_items.json"
with open(items_path, "r", encoding="utf-8") as f:
    items = json.load(f)

existing_ids = {item["id"] for item in items}

BI_KIP_180 = [
    ("6_1_18001", "Bí Kíp 180 - Kim Quyền La Hán", "Thiếu Lâm", 1220),
    ("6_1_18002", "Bí Kíp 180 - Chinh Chiến Bát Phương", "Thiên Vương", 1221),
    ("6_1_18003", "Bí Kíp 180 - Sâm La Độc Hải", "Ngũ Độc", 1222),
    ("6_1_18004", "Bí Kíp 180 - Hấp Tinh Trận", "Đường Môn", 1223),
    ("6_1_18005", "Bí Kíp 180 - Ba La Tâm Kinh", "Nga Mi", 1224),
    ("6_1_18006", "Bí Kíp 180 - Huyền Băng Vô Tắc", "Thúy Yên", 1225),
    ("6_1_18007", "Bí Kíp 180 - Liệt Hỏa Phần Thiên", "Thiên Nhẫn", 1226),
    ("6_1_18008", "Bí Kíp 180 - Ô Y Quyết", "Cái Bang", 1227),
    ("6_1_18009", "Bí Kíp 180 - Chân Võ Thất Tiết", "Võ Đang", 1228),
    ("6_1_18010", "Bí Kíp 180 - Thiên Cương Khí Kính", "Côn Lôn", 1229),
    ("6_1_18011", "Bí Kíp 180 - Độc Cô Cửu Kiếm", "Hoa Sơn", 1368),
    ("6_1_18012", "Bí Kíp 180 - Trừ Gian Diệt Nịnh", "Vũ Hồn", 1985),
    ("6_1_18013", "Bí Kíp 180 - Thập Bộ Nhất Sát", "Tiêu Dao", 1896),
    ("6_1_18014", "Bí Kíp 180 - Bôn Lang Thương", "Dương Môn", 1784),
    ("6_1_18015", "Bí Kíp 180 - Lôi Đình Nhất Kích", "Minh Giáo", 1762),
]

added_books = 0
for item_id, name, sect_name, skill_id in BI_KIP_180:
    if item_id not in existing_ids:
        new_item = {
            "id": item_id,
            "name": name,
            "genre": 6,
            "detail": 1,
            "particular": int(item_id.split("_")[-1]),
            "image": "\\spr\\item\\task\\stunt.spr",
            "width": 1,
            "height": 1,
            "intro": f"Tuyệt học thất truyền cấp 180 của môn phái {sect_name}. Sử dụng để lĩnh hội và tăng cấp võ công tiến giai.",
            "price": 500000,
            "level": 180,
            "stack": 1,
            "source": "magicscript",
            "script": "\\script\\skill\\advancedskill.lua",
            "skill_id": skill_id,
            "icon": "stunt"
        }
        items.append(new_item)
        existing_ids.add(item_id)
        added_books += 1

with open(items_path, "w", encoding="utf-8") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)
print(f"Added {added_books} Bí kíp 180 to misc_items.json!")
