"""Đồng bộ thông số skill môn phái (systems/sect/data/*.tres) với Skills.txt gốc VLTK.

    python tools/sync_skills_from_vltk.py [--dry]

Ghép skill game <-> dòng Skills.txt theo tên (như tools/mark_player_skills.py; trùng tên ưu tiên dòng người chơi học
được theo factionhead.lua). Ghi cho skill ĐANG HIỆN (skill ẩn giữ nguyên — skill cha có thể đang dựa vào nó):
  vltk_skill_id  <- SkillId
  req_level      <- ReqLevel          (cấp nhân vật tối thiểu)
  max_level      <- MaxLevel
  target_enemy/target_ally/target_self <- TargetEnemy/TargetAlly/TargetSelf
  is_aura        <- IsAura            (ngoại lệ: trạng thái không thời hạn — autodeathskill — giữ hào quang bật/tắt)
  practice_only  <- IsExpSkill        (skill tăng cấp bằng kinh nghiệm/luyện, không cộng điểm)
  weapon_limit   <- EqtLimit          (-2 không hạn chế, -1 quyền thủ, 0-5 vũ khí cận chiến, 100-102 ám khí)
  horse_limit    <- HorseLimit        (1 = không thi triển được khi cưỡi ngựa)
"""
import difflib
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import mark_player_skills as mps  # noqa: E402
from import_vltk_skill_icons import norm, FUZZY_CUTOFF, TRES_DIR  # noqa: E402

COLS = ["SkillName", "SkillId", "ReqLevel", "MaxLevel", "TargetEnemy", "TargetAlly", "TargetSelf", "IsAura",
        "IsExpSkill", "EqtLimit", "HorseLimit"]


def load_rows() -> dict:
    lines = mps.iconv(mps.SKILLS_TXT).split("\n")
    header = lines[0].split("\t")
    ci = {k: header.index(k) for k in COLS}
    rows = defaultdict(list)
    for line in lines[1:]:
        c = line.split("\t")
        if len(c) > ci["SkillId"] and c[ci["SkillId"]].strip().isdigit():
            rows[norm(c[ci["SkillName"]])].append({k: c[v].strip() for k, v in ci.items()})
    return rows


def to_int(text: str, default: int) -> int:
    try:
        return int(text)
    except ValueError:
        return default


def set_field(block: str, name: str, value: str, default: str) -> str:
    """Đặt `name = value` (bỏ dòng nếu bằng giá trị mặc định của SkillDefinition) ngay sau skill_name."""
    block = re.sub(r"^%s = .*\n" % name, "", block, flags=re.M)
    if value == default:
        return block
    m = re.search(r'^skill_name = "[^"]*"\n', block, re.M)
    return block[:m.end()] + "%s = %s\n" % (name, value) + block[m.end():]


def main():
    dry = "--dry" in sys.argv
    rows = load_rows()
    learnable = mps.player_skill_ids()
    for tres in sorted(TRES_DIR.glob("*.tres")):
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        report = []
        for bi, block in enumerate(blocks):
            name = re.search(r'^skill_name = "([^"]*)"\n', block, re.M)
            if not name or re.search(r"^is_hidden = true", block, re.M):
                continue
            key = norm(name.group(1))
            found = rows.get(key)
            if found is None:
                close = difflib.get_close_matches(key, list(rows), n=1, cutoff=FUZZY_CUTOFF)
                found = rows[close[0]] if close else None
            if not found:
                report.append("  ? %s: không ghép được Skills.txt — giữ nguyên" % name.group(1))
                continue
            r = sorted(found, key=lambda x: 0 if int(x["SkillId"]) in learnable else 1)[0]
            aura = r["IsAura"] == "1" or "autodeathskill" in block
            values = [
                ("vltk_skill_id", str(int(r["SkillId"])), "0"),
                ("req_level", str(max(1, to_int(r["ReqLevel"], 1))), "1"),
                ("max_level", str(max(1, to_int(r["MaxLevel"], 10))), "10"),
                ("target_enemy", "true" if r["TargetEnemy"] == "1" else "false", "false"),
                ("target_ally", "true" if r["TargetAlly"] == "1" else "false", "false"),
                ("target_self", "true" if r["TargetSelf"] == "1" else "false", "false"),
                ("is_aura", "true" if aura else "false", "false"),
                ("practice_only", "true" if r["IsExpSkill"] == "1" else "false", "false"),
                ("weapon_limit", str(to_int(r["EqtLimit"], -2)), "-2"),
                ("horse_limit", str(to_int(r["HorseLimit"], 0)), "0"),
            ]
            changes = []
            for field, value, default in values:
                old = re.search(r"^%s = (.*)$" % field, block, re.M)
                old_value = old.group(1).strip() if old else default
                if old_value != value:
                    changes.append("%s %s->%s" % (field, old_value, value))
                block = set_field(block, field, value, default)
            blocks[bi] = block
            if [c for c in changes if not c.startswith(("vltk_skill_id", "weapon_limit", "horse_limit"))]:
                report.append("  %s: %s" % (name.group(1), ", ".join(c for c in changes if not c.startswith("vltk_skill_id"))))
        print("\n%s" % tres.stem)
        print("\n".join(report) if report else "  (khớp)")
        if not dry:
            tres.write_text("".join(blocks), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
