"""Bảng giá thuốc (Hiệu thuốc — PotionShop) cho server tài khoản: <repo backend kiem-hiep-server>/account/potion_prices.json {misc_id: giá}.

    python tools/export_potion_prices.py

Server tài khoản (profile_guard.go) chỉ nhận thuốc MỚI do game gửi khi lưu ngoài map (mua ở Hiệu thuốc lúc đang ở Hub) nếu mã có trong bảng này
và tiền đã trừ đủ theo giá. Nguồn: data/items/misc_items.json (nguồn "potion", giá > 0) + data/items/songjin_potions.json (điểm / lượng) — cùng nguồn với PotionShop.items().
Định dạng: {"gold": {mã: lượng}, "points": {mã: điểm Tống Kim}}.
Chạy lại mỗi khi đổi dữ liệu vật phẩm.
"""
import json
import sys
import os

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, "data", "items", "misc_items.json"), encoding="utf-8") as f:
	items = json.load(f)
gold = {str(m["id"]): int(m.get("price", 0)) for m in items if m.get("source") == "potion" and int(m.get("price", 0)) > 0}
## Thuốc Tống Kim (data/items/songjin_potions.json): "points" = điểm tích lũy Tống Kim, không có thì "money" = lượng.
with open(os.path.join(ROOT, "data", "items", "songjin_potions.json"), encoding="utf-8") as f:
	songjin = json.load(f)
points = {}
for m in songjin:
	if int(m.get("points") or 0) > 0:
		points[str(m["id"])] = int(m["points"])
	elif int(m.get("money") or 0) > 0:
		gold[str(m["id"])] = int(m["money"])
prices = {"gold": gold, "points": points}
# Repo backend tách riêng, mặc định cạnh repo game; đổi bằng biến môi trường SERVER_REPO.
server_repo = os.environ.get("SERVER_REPO") or os.path.join(os.path.dirname(ROOT), "kiem-hiep-server")
dest = os.path.join(server_repo, "account", "potion_prices.json")
with open(dest, "w", encoding="utf-8", newline="\n") as f:
	json.dump(prices, f, indent=1, sort_keys=True)
print("%d thuốc trả lượng, %d thuốc trả điểm Tống Kim -> %s" % (len(gold), len(points), dest))
