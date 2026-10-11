"""Thêm CHỈ SỐ GỐC (máu, sát thương, phòng thủ, chính xác, kinh nghiệm...) của từng quái vào data/monsters/monsters.json.

    python tools/import_vltk_monster_stats.py [thư_mục_client_vng]

Nguồn: settings/npcs.txt của client VNG (trong pak) — mỗi quái có hệ số, KHÔNG có số tuyệt đối. Số thật tính theo cấp quái
bằng script gốc \script\npclevelscript (lib.lua + property.lua):
    Life / Exp / AttackRating / Defense / MinDamage / MaxDamage = floor(a*cấp^2 + b*cấp + c)   (Quadratic)
        với a,b,c = cột <Tên>Param1, Param2, Param3;   cột <Tên>Param (thường 100) là hệ số % nhân thêm.
    PhysicalDamageBase, Poison/Cold/Fire/LightingDamageBase, LifeReplenish = floor(k*cấp + c)  (Linear), cột "k|c".
Ghi vào mỗi quái:
    "series": hệ Ngũ Hành (cập nhật từ cột Series của npcs.txt VNG)
    "stats": {"life": [pct,a,b,c], "exp": [...], "attack_rating": [...], "defense": [...], "min_damage": [...], "max_damage": [...]}
    "damage_base": {"physical": [k,c], "poison": [k,c], "cold": [k,c], "fire": [k,c], "lighting": [k,c]}
    "life_replenish": [k,c], "level_script": tên script cấp (animal/makeboss/standard...)
Khớp dòng npcs.txt (VNG) với quái trong monsters.json theo số dòng (= STT), chỉ nhận khi cùng bộ tài nguyên hình;
lệch phiên bản thì thử khớp theo tên + bộ hình duy nhất, còn lại bỏ qua (in ra).
"""
import json
import os
import subprocess
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(__file__))
import vltk_pak  # noqa: E402

CLIENT = sys.argv[1] if len(sys.argv) > 1 else r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MONSTERS = os.path.join(ROOT, "data", "monsters", "monsters.json")

QUAD = {"life": "Life", "exp": "Exp", "attack_rating": "AR", "defense": "Defense",
		"min_damage": "MinDamage", "max_damage": "MaxDamage"}
LINEAR = {"physical": "PhysicalDamageBase", "poison": "PoisonDamageBase", "cold": "ColdDamageBase",
		"fire": "FireDamageBase", "lighting": "LightingDamageBase"}


def num(text: str) -> float:
	try:
		v = float(text.strip())
		return int(v) if v == int(v) else v
	except ValueError:
		return 0


def pair(text: str) -> list:
	parts = text.strip().split("|")
	return [num(parts[0]), num(parts[1]) if len(parts) > 1 else 0]


def norm(s: str) -> str:
	return unicodedata.normalize("NFC", s).strip().lower()


pl = vltk_pak.PakList.__new__(vltk_pak.PakList)
pl.client_dir, pl.paks = CLIENT, []
for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
	p = os.path.join(CLIENT, "data", n + ".pak")
	if os.path.isfile(p):
		pl.paks.append(vltk_pak.PakFile(p))
raw = pl.read("settings/npcs.txt")
text = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=raw, capture_output=True).stdout.decode("utf-8", "replace")
lines = text.split("\n")
header = [h.strip("\ufeff \r") for h in lines[0].split("\t")]
rows = [dict(zip(header, l.rstrip("\r").split("\t"))) for l in lines[1:] if l.strip()]

monsters = json.load(open(MONSTERS, encoding="utf-8"))
by_name_res: dict = {}
for i, r in enumerate(rows):
	by_name_res.setdefault((norm(r.get("Name", "")), norm(r.get("NpcResType", ""))), []).append(i)

matched = skipped = 0
for sid, m in monsters.items():
	i = int(sid)
	row = rows[i] if i < len(rows) else None
	if row is None or norm(row.get("NpcResType", "")) != norm(m["res"]):
		cand = by_name_res.get((norm(m["name"]), norm(m["res"])), [])
		row = rows[cand[0]] if len(cand) == 1 else None
	if row is None:
		skipped += 1
		print("  bỏ qua (không khớp dòng VNG):", sid, m["name"], m["res"])
		continue
	m["stats"] = {key: [num(row.get(col + "Param", "100"))] + [num(row.get("%sParam%d" % (col, k), "0")) for k in (1, 2, 3)]
				for key, col in QUAD.items()}
	m["damage_base"] = {key: pair(row.get(col, "0|0")) for key, col in LINEAR.items()}
	m["life_replenish"] = pair(row.get("LifeReplenish", "0|0"))
	## Hệ Ngũ Hành của quái: 0 Kim, 1 Mộc, 2 Thủy, 3 Hỏa, 4 Thổ (giá trị khác -> giữ nguyên hệ cũ).
	series = num(row.get("Series", "0"))
	if series in (0, 1, 2, 3, 4):
		m["series"] = int(series)
	m["level_script"] = os.path.splitext(os.path.basename(row.get("LevelScript", "").replace("\\", "/")))[0]
	matched += 1

with open(MONSTERS, "w", encoding="utf-8") as f:
	json.dump(monsters, f, ensure_ascii=False, indent=1, sort_keys=True)
print("có chỉ số:", matched, "| bỏ qua:", skipped)
