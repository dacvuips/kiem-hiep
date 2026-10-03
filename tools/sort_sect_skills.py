"""Sắp lại thứ tự skill môn phái (mảng `skills` trong systems/sect/data/*.tres) ĐÚNG như bảng kỹ năng VLTK gốc, và
đánh dấu skill cao cấp (90/120/150) là skill luyện.

    python tools/sort_sect_skills.py [--dry]

Bản gốc hiện skill theo thứ tự được thêm vào nhân vật (KSkillList::GetSkillSortList duyệt m_Skills theo thứ tự):
vào phái thì script factionhead.lua AddMagic cả bảng SKILLNORMAL[phái] theo thứ tự -> rồi skill 90 (SKILL90_ARRAY),
120 (SKILL120AR, 1 id mỗi phái theo thứ tự phái), 150 (SKILL150_ARRAY) khi học. Skill game ghép SkillId theo tên
(như tools/mark_player_skills.py). Skill không có trong bảng gốc xếp sau; skill ẩn (is_hidden) xếp cuối cùng.

Nhóm 90/120/150 chỉ được LIỆT KÊ để đối chiếu; practice_only/req_level đồng bộ từ Skills.txt bằng
tools/sync_skills_from_vltk.py (IsExpSkill/ReqLevel).
"""
import difflib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import mark_player_skills as mps  # noqa: E402
from import_vltk_skill_icons import norm, FUZZY_CUTOFF, TRES_DIR  # noqa: E402

## Chỉ số phái trong factionhead.lua (SKILLNORMAL[1..10]; SKILL120AR theo cùng thứ tự, đếm từ 0).
FACTION_INDEX = {"thieu_lam": 1, "thien_vuong_bang": 2, "duong_mon": 3, "ngu_doc_giao": 4, "nga_mi": 5,
                 "thuy_yen_mon": 6, "cai_bang": 7, "thien_nhan_giao": 8, "vo_dang": 9, "con_lon": 10}
SKILL90_REQ_LEVEL = 80
ADVANCED_TIER = {}  ## SkillId -> 90/120/150


def faction_blocks(text: str, table: str) -> dict:
    body = mps.lua_table(text, table)
    out = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*\{", body):
        i, depth = m.end() - 1, 0
        while True:
            depth += {"{": 1, "}": -1}.get(body[i], 0)
            if depth == 0:
                break
            i += 1
        out[int(m.group(1))] = body[m.end():i]
    return out


def original_order() -> dict:
    """{chỉ số phái: [SkillId theo thứ tự hiển thị gốc]} + điền ADVANCED_TIER."""
    text = mps.iconv(mps.FACTION_HEAD)
    normal = faction_blocks(text, "SKILLNORMAL")
    s90 = faction_blocks(text, "SKILL90_ARRAY")
    s150 = faction_blocks(text, "SKILL150_ARRAY")
    s120 = [int(x) for x in re.findall(r"\d+", mps.lua_table(text, "SKILL120AR"))]
    out = {}
    for k in normal:
        ids = [int(x) for x in re.findall(r"\{\s*(\d+)\s*,\s*\d+\s*\}", normal[k])]
        tier90 = [int(x) for x in re.findall(r'"[^"]*"\s*,\s*(\d+)', s90.get(k, ""))]
        tier120 = [s120[k - 1]] if k - 1 < len(s120) else []
        tier150 = [int(x) for x in re.findall(r'"[^"]*"\s*,\s*(\d+)', s150.get(k, ""))]
        for tier, tier_ids in ((90, tier90), (120, tier120), (150, tier150)):
            for i in tier_ids:
                ADVANCED_TIER[i] = tier
        out[k] = ids + tier90 + tier120 + tier150
    return out


def mark_practice(block: str, tier: int) -> str:
    """Thêm practice_only (+ req_level 80 cho skill 90) ngay sau dòng skill_name."""
    block = re.sub(r"^practice_only = .*\n", "", block, flags=re.M)
    if tier == 0:
        return block
    name_m = re.search(r'^skill_name = "[^"]*"\n', block, re.M)
    block = block[:name_m.end()] + "practice_only = true\n" + block[name_m.end():]
    if tier == 90:
        if re.search(r"^req_level = ", block, re.M):
            block = re.sub(r"^req_level = .*$", "req_level = %d" % SKILL90_REQ_LEVEL, block, flags=re.M)
        else:
            block = block.replace("practice_only = true\n",
                                  "practice_only = true\nreq_level = %d\n" % SKILL90_REQ_LEVEL, 1)
    return block


def main():
    dry = "--dry" in sys.argv
    order = original_order()
    by_name = mps.skill_ids_by_name()
    for tres in sorted(TRES_DIR.glob("*.tres")):
        k = FACTION_INDEX.get(tres.stem)
        if k is None:
            continue
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        info = {}  ## SubResource id -> (tên, ẩn, SkillId ghép được)
        marked = []
        for bi, block in enumerate(blocks):
            sid = re.search(r'\[sub_resource type="Resource" id="([^"]+)"\]', block)
            name = re.search(r'^skill_name = "([^"]*)"', block, re.M)
            if not (sid and name):
                continue
            key = norm(name.group(1))
            ids = by_name.get(key)
            if ids is None:
                close = difflib.get_close_matches(key, list(by_name), n=1, cutoff=FUZZY_CUTOFF)
                ids = by_name[close[0]] if close else []
            hidden = bool(re.search(r"^is_hidden = true", block, re.M))
            info[sid.group(1)] = (name.group(1), hidden, ids)
            ## practice_only / req_level giờ đồng bộ thẳng từ Skills.txt (IsExpSkill, ReqLevel) bằng
            ## tools/sync_skills_from_vltk.py — ở đây chỉ báo nhóm 90/120/150 để đối chiếu, không ghi.
            tiers = [ADVANCED_TIER[i] for i in ids if i in ADVANCED_TIER]
            if tiers and not hidden:
                marked.append("%s(%d)" % (name.group(1), min(tiers)))
        text = "".join(blocks)

        ## dạng: skills = Array[ExtResource("..")]([SubResource("a"), ...]) hoặc skills = [...]
        m = re.search(r"^(skills = (?:Array\[[^\]]*\]\()?\[)(.*?)(\]\)?)$", text, re.M)
        current = re.findall(r'SubResource\("([^"]+)"\)', m.group(2))
        rank = {sid: i for i, sid in enumerate(order[k])}

        def sort_key(ref: str):
            _name, hidden, ids = info[ref]
            pos = min((rank[i] for i in ids if i in rank), default=None)
            group = 2 if hidden else (0 if pos is not None else 1)
            return (group, pos if pos is not None else 0, current.index(ref))

        new = sorted(current, key=sort_key)
        print("\n%s%s" % (tres.stem, "" if new != current else " (thứ tự đã đúng)"))
        print("    thứ tự:", " | ".join(info[r][0] for r in new if not info[r][1]))
        print("    nhóm 90/120/150:", ", ".join(marked))
        if new != current:
            line = m.group(1) + ", ".join('SubResource("%s")' % r for r in new) + m.group(3)
            text = text[:m.start()] + line + text[m.end():]
        if not dry:
            tres.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
