"""Đánh dấu skill THI TRIỂN ĐƯỢC (đặt lên thanh kỹ năng) đúng quy tắc VLTK gốc.

    python tools/mark_castable_skills.py [--dry]

KSkillList::GetLeftSkillSortList / GetRightSkillSortList (danh sách skill gán được cho chuột trái/phải = phím tắt):
skill đã học, đủ cấp, và (Attrib > 1 [không phải đòn cơ bản — KSkill::IsBase] và LRSkill == 0 [cả 2 phím])
hoặc LRSkill == 1 (chỉ trái) / 2 (chỉ phải). LRSkill 3 = không gán được. Cột lấy từ Skills.txt.

Skill thi triển được mà game đang để bị động (category = PASSIVE) -> chuyển ACTIVE:
  - phần lớn là "trạng thái chủ động" (SkillStyle 2 = SKILL_SS_InitiativeNpcState) chuột phải: buff có thời gian lên
    mình (Túy Điệp Cuồng Vũ, Kim Chung Tráo...) hoặc hào quang (is_aura — La Hán Trận, Thất Tinh Trận...).
  - trạng thái không có thời gian (thuộc tính autodeathskill — Ma Âm Phệ Phách) giữ suốt khi bật -> coi là hào quang.
Hào quang: bấm để bật/tắt, chỉ 1 hào quang cùng lúc (PlayerProfile.active_aura_id).
"""
import difflib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import mark_player_skills as mps  # noqa: E402
from import_vltk_skill_icons import norm, FUZZY_CUTOFF, TRES_DIR  # noqa: E402

PASSIVE_LINE = "category = 1"


def main():
    dry = "--dry" in sys.argv
    lines = mps.iconv(mps.SKILLS_TXT).split("\n")
    header = lines[0].split("\t")
    col = {k: header.index(k) for k in ("SkillName", "SkillId", "LRSkill", "Attrib")}
    rows = {}
    for line in lines[1:]:
        c = line.split("\t")
        if len(c) > col["SkillId"] and c[col["SkillId"]].strip().isdigit():
            rows.setdefault(norm(c[col["SkillName"]]), []).append(
                (int(c[col["SkillId"]]), int(c[col["LRSkill"]] or 0), int(c[col["Attrib"]] or 0)))
    learnable = mps.player_skill_ids()
    total = 0
    for tres in sorted(TRES_DIR.glob("*.tres")):
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        changed = []
        for bi, block in enumerate(blocks):
            name = re.search(r'^skill_name = "([^"]*)"\n', block, re.M)
            if not name or not re.search(r"^%s$" % PASSIVE_LINE, block, re.M):
                continue
            ## Skill ẩn (skill con / skill NPC) giữ nguyên — skill cha có thể đang dựa vào hiệu ứng bị động của nó.
            if re.search(r"^is_hidden = true", block, re.M):
                continue
            key = norm(name.group(1))
            found = rows.get(key)
            if found is None:
                close = difflib.get_close_matches(key, list(rows), n=1, cutoff=FUZZY_CUTOFF)
                found = rows[close[0]] if close else None
            if not found:
                continue
            ## trùng tên nhiều dòng: ưu tiên dòng người chơi học được
            skill_id, lr, attrib = sorted(found, key=lambda r: 0 if r[0] in learnable else 1)[0]
            castable = (attrib > 1 and lr == 0) or lr in (1, 2)
            if not castable:
                continue
            block = re.sub(r"^%s\n" % PASSIVE_LINE, "", block, flags=re.M)
            if "autodeathskill" in block and not re.search(r"^is_aura = true", block, re.M):
                block = re.sub(r"^is_aura = .*\n", "", block, flags=re.M)
                block = block.replace(name.group(0), name.group(0) + "is_aura = true\n", 1)
            blocks[bi] = block
            changed.append("%s (LR=%d)" % (name.group(1), lr))
        if changed:
            print("%s: %s" % (tres.stem, ", ".join(changed)))
            total += len(changed)
            if not dry:
                tres.write_text("".join(blocks), encoding="utf-8", newline="\n")
    print("Chuyển thi triển được: %d skill%s" % (total, " (chạy thử)" if dry else ""))


if __name__ == "__main__":
    main()
