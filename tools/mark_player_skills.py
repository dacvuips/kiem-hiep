"""Ẩn khỏi bảng Kỹ Năng những skill người chơi VLTK gốc KHÔNG học được (skill NPC/boss/biến thể lẫn vào danh sách
môn phái — chúng mượn ảnh của skill thật nên bảng bị trùng ảnh).

    python tools/mark_player_skills.py [--dry]

Danh sách skill người chơi = script/header/factionhead.lua của máy chủ gốc: SKILLNORMAL (skill theo cấp),
SKILL90_ARRAY, SKILL120AR (danh sách id trơn), SKILL150_ARRAY. Skill game <-> SkillId ghép theo TÊN với Skills.txt
(cùng cách chuẩn hoá + so gần đúng như tools/import_vltk_skill_icons.py). Skill không ghép được tên nào giữ nguyên.
Chỉ ĐẶT is_hidden = true (không bao giờ bỏ ẩn skill đang ẩn); dữ liệu skill giữ nguyên vì skill khác có thể gọi tới.
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from import_vltk_skill_icons import norm, FUZZY_CUTOFF, SKILLS_TXT, TRES_DIR  # noqa: E402
import difflib  # noqa: E402

FACTION_HEAD = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/header/factionhead.lua")


def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")


def lua_table(text: str, name: str) -> str:
    m = re.search(name + r"\s*=\s*\{", text)
    if not m:
        return ""
    depth, i = 0, m.end() - 1
    while True:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        if depth == 0:
            return text[m.end():i]
        i += 1


def player_skill_ids() -> set:
    text = iconv(FACTION_HEAD)
    ids = set()
    for table in ("SKILLNORMAL", "SKILL90_ARRAY", "SKILL150_ARRAY"):
        ## mục dạng {id, cấp} hoặc {"tên", id, cấp}
        ids |= {int(x) for x in re.findall(r'\{\s*(?:"[^"]*"\s*,\s*)?(\d+)\s*,\s*\d+\s*\}', lua_table(text, table))}
    ids |= {int(x) for x in re.findall(r"\d+", lua_table(text, "SKILL120AR"))}
    return ids


def skill_ids_by_name() -> dict:
    lines = iconv(SKILLS_TXT).split("\n")
    header = lines[0].split("\t")
    name_col, id_col = header.index("SkillName"), header.index("SkillId")
    out = defaultdict(list)
    for line in lines[1:]:
        cells = line.split("\t")
        if len(cells) > id_col and cells[id_col].strip().isdigit():
            out[norm(cells[name_col])].append(int(cells[id_col]))
    return out


def main():
    dry = "--dry" in sys.argv
    learnable = player_skill_ids()
    by_name = skill_ids_by_name()
    print("Skill người chơi học được (factionhead.lua): %d id" % len(learnable))
    total_hidden = 0
    for tres in sorted(TRES_DIR.glob("*.tres")):
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        hidden, unknown = [], []
        for bi, block in enumerate(blocks):
            name_m = re.search(r'^skill_name = "([^"]*)"\n', block, re.M)
            if not name_m or re.search(r"^is_hidden = true", block, re.M):
                continue
            key = norm(name_m.group(1))
            ids = by_name.get(key)
            if ids is None:
                close = difflib.get_close_matches(key, list(by_name), n=1, cutoff=FUZZY_CUTOFF)
                ids = by_name[close[0]] if close else None
            if ids is None:
                unknown.append(name_m.group(1))
                continue
            if any(i in learnable for i in ids):
                continue
            main_attack = bool(re.search(r"^is_main_attack = true", block, re.M))
            hidden.append(name_m.group(1) + (" [ĐÒN CHÍNH — giữ]" if main_attack else ""))
            if main_attack:
                continue  ## không ẩn đòn đánh chính mặc định của phái
            block = re.sub(r"^is_hidden = .*\n", "", block, flags=re.M)
            blocks[bi] = block[:name_m.end()] + "is_hidden = true\n" + block[name_m.end():] \
                if False else block.replace(name_m.group(0), name_m.group(0) + "is_hidden = true\n", 1)
            total_hidden += 1
        print("\n%s — ẩn %d:" % (tres.stem, len([h for h in hidden if "giữ" not in h])))
        for h in hidden:
            print("   -", h)
        if unknown:
            print("   (không ghép được tên, giữ nguyên: %s)" % ", ".join(unknown))
        if not dry:
            tres.write_text("".join(blocks), encoding="utf-8", newline="\n")
    print("\nTổng ẩn: %d skill%s" % (total_hidden, " (chạy thử, chưa ghi)" if dry else ""))


if __name__ == "__main__":
    main()
