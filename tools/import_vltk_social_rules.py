"""Nhập LUẬT XÃ HỘI VLTK gốc (tổ đội, bang hội) ra data/social/social_rules.json.

    python tools/import_vltk_social_rules.py

Nguồn (không đoán số):
  - client VNG (pak): settings/tong/Tong_Setting.ini
        [TongMaxMemberCount]  số thành viên tối đa của bang (+ thêm lúc Tống Kim/bang chiến)
        [TongCreate]          cấp nhân vật + cấp lãnh đạo tối thiểu để lập bang
        [LevelUnionNum]       SỐ NGƯỜI trong tổ đội theo CẤP LÃNH ĐẠO (KPlayerSet::m_cLeadExp.GetMemNumFromLevel / CalcCaptainPower)
        [MoneyToExp]          quỹ bang -> kinh nghiệm bang theo chu kỳ
        [DefaultCall]         tên chức vụ mặc định
  - server settings (bản Anh-Việt đang chạy): tong/Tong_setting.ini [Main] (tiền/danh vọng/phúc duyên lập bang, phí rời bang),
        tong/Tong_level.txt (cấp bang: tiền, cống hiến, số thành viên), npc/player/level_lead_exp.txt (kinh nghiệm cấp lãnh đạo)
  - hằng số C++: GameDataDef.h defTONG_MAX_DIRECTOR=7, defTONG_MAX_MANAGER=56, MAX_TEAM_MEMBER=7 (không tính đội trưởng),
        TRADE_ROOM 10x4, REPOSITORY_ROOM 6x10 x (1 + 5 rương mở rộng), MAX_PASSWORD_LENGTH=16, mở khoá món đồ 259200 giây.
"""
import configparser
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
import vltk_pak  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
VNG_CLIENT = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
SERVER = Path(r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\settings")
OUT = ROOT / "data" / "social" / "social_rules.json"


def vng_read(path):
    paks = vltk_pak.PakList.__new__(vltk_pak.PakList)
    paks.client_dir, paks.paks = VNG_CLIENT, []
    for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
        f = os.path.join(VNG_CLIENT, "data", n + ".pak")
        if os.path.isfile(f):
            paks.paks.append(vltk_pak.PakFile(f))
    return paks.read(path)


def parse_ini(data: bytes):
    cp = configparser.ConfigParser(strict=False, interpolation=None, allow_no_value=True, comment_prefixes=("//", ";", "#"))
    cp.optionxform = str
    text = data.decode("gbk", "replace")
    cp.read_string("\n".join(l for l in text.splitlines() if not l.lstrip().startswith(("//", ";"))))
    return cp


def int_of(v, default=0):
    try:
        return int(str(v).strip().split()[0])
    except (ValueError, IndexError):
        return default


def main():
    raw = vng_read("settings/tong/Tong_Setting.ini")
    if raw is None:
        raise SystemExit("Không thấy Tong_Setting.ini trong pak VNG")
    vng = parse_ini(raw)
    srv = parse_ini((SERVER / "tong" / "Tong_setting.ini").read_bytes())

    union = {int(k): int_of(v) for k, v in vng["LevelUnionNum"].items()}
    lead_rows = (SERVER / "npc" / "player" / "level_lead_exp.txt").read_bytes().decode("gbk", "replace").splitlines()[1:]
    lead_exp = {}
    for line in lead_rows:
        c = line.split("\t")
        if len(c) > 2 and c[0].strip().isdigit():
            lead_exp[int(c[0])] = int_of(c[1])
    tong_rows = (SERVER / "tong" / "Tong_level.txt").read_bytes().decode("gbk", "replace").splitlines()[1:]
    tong_levels = []
    for line in tong_rows:
        c = line.split("\t")
        if len(c) >= 4 and c[0].strip().isdigit():
            tong_levels.append({"level": int(c[0]), "money": int_of(c[1]), "devote": int_of(c[2]), "member": int_of(c[3])})
    level_exp = {int(k): int_of(v) for k, v in vng["LevelExp"].items() if k.isdigit()}
    m2e = vng["MoneyToExp"]
    main_s = srv["Main"]
    rules = {
        "source": "VNG pak settings/tong/Tong_Setting.ini + server settings (xem docstring tools/import_vltk_social_rules.py)",
        "team": {
            "max_members_without_captain": 7,
            "union_num_by_lead_level": {str(k): v for k, v in sorted(union.items())},
            "lead_exp_to_next": {str(k): v for k, v in sorted(lead_exp.items())},
            "max_apply_list": 32,
            "pick_modes": ["self", "free", "captain", "alternate"],
        },
        "tong": {
            "max_member": int_of(vng["TongMaxMemberCount"]["TongMaxMemberCount"]),
            "ws_war_add_member": int_of(vng["TongMaxMemberCount"]["TongWSWarAddMemberCount"]),
            "max_director": 7,
            "max_manager": 56,
            "name_max_length": 12,
            "create": {
                "level": int_of(vng["TongCreate"]["Level"]),
                "lead_level": int_of(vng["TongCreate"]["LeadLeval"]),
                "money": int_of(main_s["RequireMn"]),
                "repute": int_of(main_s["RequireRp"]),
                "fuyuan": int_of(main_s["RequireFy"]),
                "item": str(main_s["RequireItem"]).strip(),
            },
            "leave": {"money": int_of(main_s["LeavMn"]), "repute": int_of(main_s["LeaveRp"]), "seconds": int_of(main_s["LeaveTm"])},
            "test_period": {"min_member": int_of(vng["TongTest"]["MinMember"]), "seconds": int_of(vng["TongTest"]["TimeLong"])},
            "money_to_exp": {k: int_of(v) for k, v in m2e.items()},
            "level_exp": {str(k): v for k, v in sorted(level_exp.items())},
            "levels": tong_levels,
            "default_call": {"master": "Bang Chủ", "director": "Trưởng Lão", "manager": "Đội Trưởng", "normal": "Đệ Tử", "retire": "Ẩn Sĩ"},
        },
        "box": {
            "room_width": 6, "room_height": 10, "extra_boxes": 5,
            "trade_room_width": 10, "trade_room_height": 4,
            "max_password_length": 16, "item_unlock_seconds": 259200,
        },
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(rules, ensure_ascii=False, indent=1), encoding="utf-8")
    print("ghi", OUT, "| lead_level:", len(union), "| lead_exp:", len(lead_exp), "| tong_level:", len(tong_levels), "| create:", rules["tong"]["create"])


if __name__ == "__main__":
    main()
