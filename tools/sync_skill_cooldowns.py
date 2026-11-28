"""Đồng bộ HỒI CHIÊU RIÊNG của skill trong systems/sect/data/*.tres theo VLTK gốc.

VLTK gốc không có hồi chiêu cho đa số chiêu đánh — nhịp ra đòn do độ dài động tác (18 frame ngoại công / 20 frame nội công,
SectSkillController.action_seconds). Hồi chiêu riêng của skill (KSkill::GetDelayPerCast -> NextCastTime) chỉ đến từ:
  - cột TimePerCast của Skills.txt (frame, 18 frame/giây)      -> field `cooldown` (giây)
  - lua skill_mintimepercast_v (khi LvlSettingN của Skills.txt khai báo nó — chỉ skill 120), đổi theo cấp
                                                              -> field `vltk_min_time_per_cast` (mốc cấp, frame)

    python tools/sync_skill_cooldowns.py           # ghi vào .tres
    python tools/sync_skill_cooldowns.py --dry     # chỉ in thay đổi
    python tools/sync_skill_cooldowns.py nga_mi    # chỉ các phái này

Nguồn giống tools/import_vltk_hit_effects.py: 9 phái cũ = Skills.txt pak client VNG + lua client; 5 phái mới + Ngũ Độc =
server 15 phái (tools/vltk_source.py, cần `python tools/vltk_source.py --extract` trước). Skill không có SkillId trong bảng
gốc thì giữ nguyên và in ra.
"""
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_vltk_hit_effects as hit  # noqa: E402  (nạp sẵn đường dẫn Skills.txt VNG / 15 phái + parser lua)

FPS = 18.0


def load_cast_columns(path):
    """SkillId -> (TimePerCast, script lua, bảng lua chứa skill_mintimepercast_v hoặc "")."""
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    lines = raw.splitlines()
    header = lines[0].split("\t")
    col = {h: i for i, h in enumerate(header)}
    out = {}
    for line in lines[1:]:
        cells = line.split("\t")
        cells += [""] * (len(header) - len(cells))
        sid = hit.to_int(cells[col["SkillId"]])
        if sid <= 0:
            continue
        table = ""
        n = 1
        while f"LvlSetting{n}" in col:
            if cells[col[f"LvlSetting{n}"]].strip() == "skill_mintimepercast_v":
                table = cells[col[f"LvlData{n}"]].strip()
                break
            n += 1
        script = cells[col["LvlSetScript"]].strip().replace("\\", "/").lstrip("/")
        out[sid] = (hit.to_int(cells[col["TimePerCast"]]), script, table)
    return out


def fmt_seconds(frames: int) -> str:
    return f"{frames / FPS:.2f}"


def main():
    dry = "--dry" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    old_cols = load_cast_columns(hit.SKILLS_TXT)
    new_cols = load_cast_columns(hit.NEW_SKILLS_TXT)
    changes, unmatched = [], []
    for tres in sorted(hit.TRES_DIR.glob("*.tres")):
        if only and tres.stem not in only:
            continue
        is_new = tres.stem in hit.NEW_SECTS
        cols = new_cols if is_new else old_cols
        lua_dirs = hit.NEW_LUA_DIRS if is_new else hit.LUA_DIRS
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        changed = False
        for bi, block in enumerate(blocks):
            name_m = re.search(r'^skill_name = "([^"]*)"', block, re.M)
            cd_m = re.search(r"^cooldown = (.*)$", block, re.M)
            if not name_m or not cd_m:
                continue
            id_m = re.search(r"^vltk_skill_id = (\d+)", block, re.M)
            sid = int(id_m.group(1)) if id_m else 0
            ## Ngũ Độc lấy số liệu bản 15 phái nhưng vẫn là phái cũ: skill bản 15 phái không có (VD 1222) thì tra bảng VNG.
            row_cols, row_lua = cols, lua_dirs
            if sid not in cols and is_new and tres.stem not in hit.vltk_source.NEW_SECTS and sid in old_cols:
                row_cols, row_lua = old_cols, hit.LUA_DIRS
            if sid not in row_cols:
                unmatched.append(f"{tres.stem}: {name_m.group(1)} (id {sid}) cooldown {cd_m.group(1)}")
                continue
            tpc, script, table = row_cols[sid]
            new_block = re.sub(r"^vltk_min_time_per_cast = .*\n", "", block, flags=re.M)
            new_cd = fmt_seconds(tpc)
            new_block = re.sub(r"^cooldown = .*$", f"cooldown = {new_cd}", new_block, count=1, flags=re.M)
            points = ""
            if table:
                parsed = hit.lua_attr(script, table, "skill_mintimepercast_v", row_lua)
                if isinstance(parsed, list) and parsed and parsed[0]:
                    points = hit.points_literal(parsed[0])
                    line_end = re.search(r"^cooldown = .*\n", new_block, re.M).end()
                    new_block = new_block[:line_end] + f"vltk_min_time_per_cast = {points}\n" + new_block[line_end:]
            if new_block != block:
                blocks[bi] = new_block
                changed = True
                changes.append(f"{tres.stem:18} {name_m.group(1):38} id {sid:5}  {cd_m.group(1):>5} -> {new_cd}"
                               + (f"  theo cấp {points}" if points else ""))
        if changed and not dry:
            tres.write_text("".join(blocks), encoding="utf-8", newline="\n")
    print("\n".join(changes))
    print(f"\nĐổi {len(changes)} skill.")
    if unmatched:
        print(f"\nKhông có trong Skills.txt gốc (giữ nguyên, {len(unmatched)}):")
        print("\n".join("  " + u for u in unmatched))


if __name__ == "__main__":
    main()
