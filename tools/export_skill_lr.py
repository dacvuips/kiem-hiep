"""Bảng skill gán được cho CHUỘT TRÁI / CHUỘT PHẢI theo Skills.txt gốc -> data/skill_fx/skill_lr.json.

Gốc: KSkillList::GetLeftSkillSortList / GetRightSkillSortList (Core/Src/KSkillList.cpp) — với SkillStyle Missles / Melee /
InitiativeNpcState / PassivityNpcState, skill chỉ vào danh sách khi (không phải đòn cơ bản [KSkill::IsBase] và LRSkill == 0
[cả 2 phím]) hoặc LRSkill == 1 (chỉ trái) / 2 (chỉ phải); kiểu khác (Thief bị loại ở bên trái) giữ nguyên. LRSkill 3 = không gán.
Ô đầu cả 2 danh sách luôn là đòn vũ khí đang cầm (GetCurActiveWeaponSkill).

Cột LRSkill, Attrib (KSkill::IsBase: Attrib <= 1 — như tools/mark_castable_skills.py), SkillStyle lấy từ Skills.txt bản VNG
(10 phái cũ) rồi bổ sung SkillId còn thiếu từ bản 15 phái (5 phái mới).

    python tools/export_skill_lr.py
JSON: {"<SkillId>": [LRSkill, is_base (0/1), SkillStyle]}
"""
import json
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import vltk_source  # noqa: E402

VNG_SKILLS_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt")
OUT = HERE.parent / "data" / "skill_fx" / "skill_lr.json"


def _rows(path: Path) -> dict:
	if not path.exists():
		print("THIẾU", path)
		return {}
	lines = path.read_bytes().decode("gbk", "replace").replace("\r", "").split("\n")
	header = lines[0].split("\t")
	col = {k: header.index(k) for k in ("SkillId", "LRSkill", "Attrib", "SkillStyle")}
	out = {}
	for line in lines[1:]:
		c = line.split("\t")
		if len(c) <= max(col.values()):
			continue
		try:
			sid = int(c[col["SkillId"]])
		except ValueError:
			continue

		def num(k):
			try:
				return int(c[col[k]] or 0)
			except ValueError:
				return 0
		out[sid] = [num("LRSkill"), 1 if num("Attrib") <= 1 else 0, num("SkillStyle")]
	return out


def main():
	table = _rows(VNG_SKILLS_TXT)
	added = 0
	for sid, row in _rows(vltk_source.settings_file("skills.txt")).items():
		if sid not in table:
			table[sid] = row
			added += 1
	OUT.parent.mkdir(parents=True, exist_ok=True)
	data = {str(k): table[k] for k in sorted(table)}
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
		f.write("\n")
	print("%d skill (%d thêm từ bản 15 phái) -> %s" % (len(data), added, os.path.relpath(OUT)))


if __name__ == "__main__":
	main()
