"""CHỈ SỐ QUÁI THEO HỆ + CẤP bằng chính SCRIPT CẤP GỐC (script/npclevelscript/*.lua của server VLTK 15 phái).

Engine gốc, mỗi lần sinh 1 quái (hệ + cấp do điểm sinh trên map quyết định), gọi script cấp ghi ở cột LevelScript của npcs.txt:
    GetNpcLevelData(Series, Level, <tên cột>, <chuỗi trong cột>)   -> Skill1..4, Level1..4, kháng, sát thương cơ bản, AI...
    GetNpcKeyData(Series, Level, <Exp|Life|AttackRating|Defense|MinDamage|MaxDamage>, Param1, Param2, Param3)
VD animal.lua: Skill1-3 = 419..423 THEO HỆ (cận chiến ngũ hành), Skill4 = 416 từ cấp 60; sát thương nội công theo hệ; kháng theo hệ.
Script chạy bằng Lua thật (lupa) — không chép tay công thức.

Kết quả: data/monsters/npc_levels.json
    {"levels": LMAX, "pool": [[giá trị cấp 1..LMAX], ...],
     "npcs": {"<id quái>": {"<hệ 0-4>": {"<trường>": chỉ số trong pool}}}}
Mảng giống nhau dùng chung 1 phần tử pool (đa số quái cùng script + cùng tham số).

    python -m pip install --user lupa
    python tools/import_vltk_npc_levels.py
"""
import json
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import vltk_source  # noqa: E402
from lupa import lua54  # noqa: E402

MONSTERS = os.path.join(ROOT, "data", "monsters", "monsters.json")
OUT = os.path.join(ROOT, "data", "monsters", "npc_levels.json")
LMAX = 150
## Trường GetNpcLevelData (tên = tên cột npcs.txt, chuỗi tham số = nội dung cột).
LEVEL_FIELDS = ["Skill1", "Level1", "Skill2", "Level2", "Skill3", "Level3", "Skill4", "Level4",
	"FireResist", "ColdResist", "LightResist", "PoisonResist", "PhysicsResist",
	"PhysicalDamageBase", "PhysicalMagicBase", "PoisonDamageBase", "PoisonMagicBase", "ColdDamageBase", "ColdMagicBase",
	"FireDamageBase", "FireMagicBase", "LightingDamageBase", "LightingMagicBase", "LifeReplenish",
	"AIMode", "AIParam1", "AIParam2", "AIParam3", "AIParam4", "AIParam5", "AIParam6", "AIParam7", "AIParam8", "AIParam9",
	"AuraSkillId", "AuraSkillLevel", "PasstSkillId", "PasstSkillLevel"]
## Trường GetNpcKeyData -> cột tham số (Param1..3) + cột hệ số % (<cột>, thường 100).
KEY_FIELDS = {"Exp": "ExpParam", "Life": "LifeParam", "AttackRating": "ARParam", "Defense": "DefenseParam",
	"MinDamage": "MinDamageParam", "MaxDamage": "MaxDamageParam"}

## Lua đời cũ (4.0/5.0) của engine -> Lua 5.4.
SHIM = r"""
getn = function(t) return #t end
strfind = string.find  strsub = string.sub  strlen = string.len  strupper = string.upper  strlower = string.lower
format = string.format  floor = math.floor  ceil = math.ceil  abs = math.abs  sqrt = math.sqrt  mod = math.fmod
tinsert = table.insert  tremove = table.remove
random = function(a, b) error("random") end
print = function(...) end
"""


def load_rows():
	raw = open(vltk_source.settings_file("npcs.txt"), "rb").read()
	text = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=raw, capture_output=True).stdout.decode("utf-8", "replace")
	lines = text.split("\n")
	header = [h.strip("﻿ \r") for h in lines[0].split("\t")]
	return [dict(zip(header, l.rstrip("\r").split("\t"))) for l in lines[1:] if l.strip()]


class ScriptRunner:
	"""1 Lua riêng cho mỗi script cấp (script định nghĩa hàm toàn cục trùng tên nhau)."""

	def __init__(self):
		self._lua = {}

	def get(self, script_path):
		key = script_path.lower().replace("/", "\\")
		if key not in self._lua:
			lua = lua54.LuaRuntime(unpack_returned_tuples=True)
			lua.execute(SHIM)
			loaded = set()

			def include(path):
				p = str(path).lower().replace("/", "\\")
				if p in loaded:
					return
				loaded.add(p)
				lua.execute(self._source(p))
			lua.globals().Include = include
			include(key)
			self._lua[key] = lua
		return self._lua[key]

	@staticmethod
	def _source(path):
		rel = path.strip("\\").replace("\\", "/")
		full = os.path.join(str(vltk_source.SERVER), rel)
		if not os.path.isfile(full):   ## không phân biệt hoa thường như Windows
			cur = str(vltk_source.SERVER)
			for part in rel.split("/"):
				hit = [c for c in os.listdir(cur) if c.lower() == part.lower()] if os.path.isdir(cur) else []
				cur = os.path.join(cur, hit[0] if hit else part)
			full = cur
		return open(full, "rb").read().decode("gbk", "replace")


def to_int(v):
	try:
		return int(float(v))
	except (TypeError, ValueError):
		return 0


def num(s):
	try:
		return float(str(s).strip())
	except ValueError:
		return 0.0


field_errors = {}


def _call_level(fn, series, lv, field, param, script):
	"""1 trường GetNpcLevelData. Script lỗi (VD GetParam đọc tham số thứ 2 của cột chỉ có 1 số -> nil + 1) -> như engine: bỏ qua
	script, dùng số trong cột (không có thì 0)."""
	try:
		return to_int(fn(series, lv, field, param))
	except Exception:  # noqa: BLE001
		field_errors[(script, field)] = field_errors.get((script, field), 0) + 1
		return to_int(param.split("|")[0]) if param else 0


def main():
	monsters = json.load(open(MONSTERS, encoding="utf-8"))
	rows = load_rows()
	runner = ScriptRunner()
	pool, pool_index = [], {}

	def intern(values):
		t = tuple(values)
		if t not in pool_index:
			pool_index[t] = len(pool)
			pool.append(list(t))
		return pool_index[t]

	out, ok, skipped, failed = {}, 0, 0, {}
	for sid, m in monsters.items():
		i = int(sid)
		row = rows[i] if i < len(rows) else None
		script = (row or {}).get("LevelScript", "").strip()
		if row is None or script == "" or row.get("NpcResType", "").strip().lower() != str(m.get("res", "")).lower():
			skipped += 1
			continue
		try:
			lua = runner.get(script)
			level_fn = lua.globals().GetNpcLevelData
			key_fn = lua.globals().GetNpcKeyData
			per_series = {}
			for series in range(5):
				fields = {}
				for f in LEVEL_FIELDS:
					if level_fn is None:
						break
					param = row.get(f, "").strip()
					fields[f] = intern(_call_level(level_fn, series, lv, f, param, script) for lv in range(1, LMAX + 1))
				for f, col in KEY_FIELDS.items():
					if key_fn is None:
						break
					p = [num(row.get("%s%d" % (col, k), "0")) for k in (1, 2, 3)]
					pct = num(row.get(col, "100")) or 100.0
					fields[f] = intern(int(to_int(key_fn(series, lv, f, p[0], p[1], p[2])) * pct / 100.0) for lv in range(1, LMAX + 1))
				per_series[str(series)] = fields
			out[sid] = per_series
			ok += 1
		except Exception as e:  # noqa: BLE001 — 1 script lỗi không dừng cả lô
			failed[script] = failed.get(script, 0) + 1
			if failed[script] == 1:
				print("LỖI", script, "-", str(e)[:200])
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		json.dump({"levels": LMAX, "pool": pool, "npcs": out}, f, separators=(",", ":"))
	print("trường dùng số trong cột (script lỗi):", sorted({f for (_s, f) in field_errors}))
	print("quái có dữ liệu: %d | bỏ qua: %d | lỗi: %s | pool: %d mảng | %d KB"
		% (ok, skipped, failed, len(pool), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
	main()
