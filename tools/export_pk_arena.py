"""Xuất ĐẤU TRƯỜNG PK (popup PK: Đại hội võ lâm / Võ lâm Liên đấu) vào game: world/maps/map_397/.

Nguồn: map 397 "Đấu Trường Liên Đấu Kiệt Xuất" của VLTK gốc (特殊用地/联赛比赛用地 — map đấu của missions/leaguematch và
missions/championship). Map gốc là 1 lưới ô đấu có rào (56 x 28 region, ~100MB nếu xuất cả) -> chỉ lấy khối 10 x 6 region ở
giữa (cùng cách chọn khối của Vượt Ải: make_vuotai.centre_block), KHÔNG đặt quái.

    python tools/export_pk_arena.py            # tạo map pk/dau_truong trong tool map (nếu chưa có) rồi xuất
    python tools/export_pk_arena.py --plan     # chỉ in khối sẽ lấy

Cần tool map (D:/game/tool/editor_map) — script tự bật server API nếu chưa chạy (giống export_training_maps.py).
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_training_maps as etm  # noqa: E402
import export_vuotai_maps as evm  # noqa: E402

SOURCE_MAP = 397
TOOL_MAP = "pk/dau_truong"
DEST = os.path.join(etm.OUT_DIR, "map_%d" % SOURCE_MAP)
PARTS = ["obstacle", "trap", "scene"]   # không lấy NPC (map đấu gốc không có quái)


def make_tool_map(plan_only):
	sys.path.insert(0, etm.TOOL_DIR)
	sys.path.insert(0, os.path.join(etm.TOOL_DIR, "worldgen"))
	import server        # noqa: E402 — module của tool map
	import make_vuotai   # noqa: E402
	server.init_vng()
	server.INDEX = server.MapIndex()
	src = make_vuotai.source_map(SOURCE_MAP)
	x0, y0, block = make_vuotai.centre_block(src["regions"])
	print("Map %d (%s): khối %d,%d — %d region -> %s" % (SOURCE_MAP, src["id"], x0, y0, len(block), TOOL_MAP))
	if plan_only:
		return None
	if TOOL_MAP in server.INDEX.maps:
		print("    %s đã có trong tool map, giữ nguyên" % TOOL_MAP)
	else:
		server.new_map(TOOL_MAP, block[0][0], block[0][1])
		server.paste_regions(src["id"], block, TOOL_MAP, 0, 0, PARTS)
		print("    đã tạo %s" % TOOL_MAP)
	return {"source": SOURCE_MAP, "tool_map": TOOL_MAP, "block": [x0, y0, make_vuotai.BW, make_vuotai.BH]}


def main():
	plan_only = "--plan" in sys.argv
	info = make_tool_map(plan_only)
	if plan_only:
		return
	proc = etm.ensure_server()
	try:
		etm.http("/api/rescan")            # server đang chạy nạp lại danh sách map (thấy map vừa tạo)
		evm.export_map(TOOL_MAP, DEST)
	finally:
		if proc is not None:
			proc.terminate()
	with open(os.path.join(DEST, "pk_arena.json"), "w", encoding="utf-8", newline="\n") as f:
		json.dump(info, f, ensure_ascii=False, indent=1)
	print("Xong -> %s" % DEST)


if __name__ == "__main__":
	main()
