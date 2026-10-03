"""Nhập dữ liệu NHÂN VẬT GHÉP BỘ PHẬN từ client VLTK gốc -> data/avatar/<gender>.json + PNG (assets/avatar/<gender>/).

    python tools/import_vltk_avatar.py [male|female]

Nguồn (client gốc, settings/npcres — tên file gốc tiếng Trung, ở đây chỉ dùng để mở file):
  - bảng bộ phận (đầu, tóc, vai, thân, tay trái/phải, vũ khí trái/phải): mỗi hàng = 1 mã hình, mỗi cột = 1 động tác
    (thứ tự cột = bảng mã động tác), ô = tên file .spr.
  - bảng liên kết vũ khí -> động tác (chưa cưỡi ngựa): mỗi hàng = 1 mã hình vũ khí, cột = Đứng chiến đấu, Chạy,
    Bị đánh, Chết, Đánh 1, Đánh 2, Thi triển...
  - bảng thứ tự vẽ: [DEFAULT]/[tên động tác], DirN = thứ tự lớp cho hướng sprite N-1 (sprite 8 hướng dùng Dir1..8),
    LineN = "số frame tổng, thứ tự..." ghi đè cho đúng 1 frame. -1 = bóng.
  - bảng bóng theo động tác.
  - server settings/item/*Res.txt: món đồ -> mã hình, theo KItemChangeRes.cpp (hàng = particular*10 + level + 2,
    giá trị - 2 = mã hình = chỉ số hàng trong bảng bộ phận).
Sprite lấy qua tools/vltk_pak.py (file rời hoặc trong .pak).

Đầu ra:
  data/avatar/male.json — key tiếng Anh (không giữ chữ Hán), xem _build() cuối file.
  assets/avatar/male/<tên spr>.png (+ .import "keep": Godot không nhập, game tự đọc PNG) — sheet đã cắt sát nội dung: cột = frame trong 1 hướng, hàng = 8 hướng; offset
  (góc trên trái phần cắt trong khung gốc 320x320) ghi trong json. Mọi bộ phận chung khung 320x320 nên chỉ cần
  đặt mỗi lớp tại offset là khớp.

ĐỢT HÌNH: chỉ xuất mã hình trong EXPORT (mở rộng dần bằng cách thêm mã rồi chạy lại). Mã không xuất thì game lùi
về hình mặc định.
"""
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from vltk_pak import PakList  # noqa: E402
import spr_to_png  # noqa: E402

CLIENT = r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK"
ITEM_SETTINGS = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/item"
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

GENDERS = {
    ## gender: (tiền tố bảng gốc "nhân vật nam"/"nhân vật nữ", thư mục sprite)
    "male": ("\u7537\u4e3b\u89d2", "spr/npcres/man"),
    "female": ("\u5973\u4e3b\u89d2", "spr/npcres/woman"),
}
## Bộ phận: key game -> (số thứ tự lớp gốc dùng trong bảng thứ tự vẽ, hậu tố tên bảng gốc)
PARTS = {
    "head": (0, "\u5934\u90e8"),          # đầu
    "hair": (1, "\u53d1\u578b"),          # tóc
    "shoulder": (4, "\u80a9\u8180"),      # vai
    "body": (5, "\u8eaf\u4f53"),          # thân
    "left_hand": (6, "\u5de6\u624b"),     # tay trái
    "right_hand": (7, "\u53f3\u624b"),    # tay phải
    "left_weapon": (8, "\u5de6\u624b\u6b66\u5668"),    # vũ khí tay trái
    "right_weapon": (9, "\u53f3\u624b\u6b66\u5668"),   # vũ khí tay phải
    "horse_front": (12, "\u9a6c\u524d"),    # đầu ngựa
    "horse_middle": (13, "\u9a6c\u4e2d"),   # thân ngựa
    "horse_back": (14, "\u9a6c\u540e"),     # mông ngựa
}
## Nhóm trang bị -> bộ phận nó quyết định (KNpcRes::SetHelm/SetArmor/SetWeapon).
GROUPS = {"helm": ["head", "hair"], "armor": ["shoulder", "body", "left_hand", "right_hand"],
          "weapon": ["left_weapon", "right_weapon"], "horse": ["horse_front", "horse_middle", "horse_back"]}
## Bộ phận chính của mỗi nhóm — có hình 1 trong các bộ phận này mới tính là có mã hình đó.
MAIN_PART = {"helm": ["head"], "armor": ["body"], "weapon": ["right_weapon", "left_weapon"], "horse": ["horse_front"]}
TABLE_ACTION_ID = "\u52a8\u4f5c\u7f16\u53f7\u8868"        # bảng mã động tác
TABLE_WEAPON_ACTIONS = "\u672a\u9a91\u9a6c\u5173\u8054\u8868"   # bảng liên kết vũ khí -> động tác (không cưỡi ngựa)
TABLE_RIDE_ACTIONS = "\u9a91\u9a6c\u5173\u8054\u8868"       # bảng liên kết vũ khí -> động tác KHI CƯỠI NGỰA
TABLE_DRAW_ORDER = "\u8d34\u56fe\u987a\u5e8f\u8868"        # bảng thứ tự vẽ
TABLE_SHADOW = "\u4e3b\u89d2\u52a8\u4f5c\u9634\u5f71\u5bf9\u5e94\u8868"  # bảng bóng theo động tác (chung nam/nữ)
## Cột bảng liên kết vũ khí -> động tác game.
WEAPON_ACTION_COLUMNS = {"stand": "FightStand", "run": "FightRun", "hurt": "Wound", "die": "Die",
                         "attack": "Attack1", "attack2": "Attack2", "cast": "Magic"}

## Đợt hình xuất ra (mã hình = chỉ số hàng bảng bộ phận). None = tự chọn theo món đồ trong game (xem _auto_export).
## Hiện tại: None cho cả 4 = MỌI mã hình mà đồ trong game dùng (đồ thường + hoàng kim, ngựa).
EXPORT = {"helm": None, "armor": None, "weapon": None, "horse": None}
## Chỉ xuất các động tác game đang dùng (key WEAPON_ACTION_COLUMNS) — thêm "hurt"/"die"/"attack2" khi game dùng tới.
## Bỏ 3 động tác chưa dùng giảm ~40% dung lượng.
USED_ACTIONS = ["stand", "run", "attack", "cast"]
DIRS = 8


def _real(name):
    try:
        return name.encode("latin1").decode("gbk")
    except UnicodeError:
        return name


class Tables:
    def __init__(self):
        d = os.path.join(CLIENT, "settings", "npcres")
        self.files = {_real(n): os.path.join(d, n) for n in os.listdir(d)}

    def lines(self, name):
        return open(self.files[name], "rb").read().decode("gbk", "replace").splitlines()

    def tab(self, name):
        rows = [r.split("\t") for r in self.lines(name) if r.strip()]
        return rows[0], rows[1:]


def read_item_res(file_name):
    """*Res.txt -> {số hàng KTabFile (1 = tiêu đề): giá trị cột 2}."""
    rows = open(os.path.join(ITEM_SETTINGS, file_name), "rb").read().decode("gbk", "replace").splitlines()
    out = {}
    for i, line in enumerate(rows, 1):
        cols = line.split("\t")
        if i > 1 and len(cols) > 1 and cols[1].strip().lstrip("-").isdigit():
            out[i] = int(cols[1])
    return out


def item_res_maps():
    """Theo KItemChangeRes: key = particular*10 + level (level 0 = không mặc gì) -> mã hình."""
    helm, armor = read_item_res("HelmRes.txt"), read_item_res("ArmorRes.txt")
    melee, rng = read_item_res("MeleeRes.txt"), read_item_res("RangeRes.txt")
    horse = read_item_res("HorseRes.txt")
    maps = {"helm": {}, "armor": {}, "melee": {}, "range": {}, "horse": {}}
    maps["helm"][0] = helm.get(2, 19) - 2
    maps["armor"][0] = armor.get(2, 19) - 2
    maps["melee"][0] = melee.get(2, 2) - 2
    for particular in range(40):
        for level in range(1, 11):
            key = particular * 10 + level
            row = key + 2
            if row in helm:
                maps["helm"][key] = helm[row] - 2
            if row in armor:
                maps["armor"][key] = armor[row] - 2
            if row in horse:  ## GetHorseRes: level 0 = không có ngựa (-1)
                maps["horse"][key] = horse[row] - 2
            if row in melee:
                maps["melee"][key] = melee[row] - 2
            if row - 1 in rng:  ## vũ khí tầm xa: GetInteger(nRow - 1) — không có hàng mặc định
                maps["range"][key] = rng[row - 1] - 2
    return maps


def read_draw_order(tables, prefix):
    order, sec = {}, None
    for line in tables.lines(prefix + TABLE_DRAW_ORDER + ".txt"):
        line = line.strip()
        m = re.match(r"\[(.*)\]", line)
        if m:
            sec = m.group(1)
            order[sec] = {"dirs": {}, "lines": {}}
            continue
        if "=" not in line or sec is None:
            continue
        key, value = line.split("=", 1)
        nums = [int(x) for x in value.split(",") if x.strip().lstrip("-").isdigit()]
        if key.startswith("Dir") and key[3:].isdigit():
            ## Số đầu = cột "số frame" (bỏ trống -1 ở dòng DirN) — GetSort chép thứ tự từ phần tử thứ 2.
            order[sec]["dirs"][int(key[3:])] = nums[1:]
        elif key.startswith("Line") and key[4:].isdigit() and nums:
            order[sec]["lines"][nums[0]] = nums[1:]
    return order


def resolve_order(order, action):
    """Thứ tự lớp cho 8 hướng + ghi đè theo frame của 1 động tác (CSortTable::GetSort)."""
    default = order["DEFAULT"]["dirs"]
    sec = order.get(action, {"dirs": {}, "lines": {}})
    dirs = [sec["dirs"].get(d + 1, default.get(d + 1, [])) for d in range(DIRS)]
    return {"dirs": dirs, "frames": {str(k): v for k, v in sec["lines"].items()}}


def _auto_export(maps, weapon_rows):
    """MỌI mã hình mà đồ trong game dùng: mũ/áo/vũ khí/ngựa của đồ thường (theo KItemChangeRes) + mũ/áo/vũ khí
    hoàng kim có hình riêng (GoldEquipRes) + hình mặc định khi ô trống."""
    out = {"helm": {maps["helm"][0]}, "armor": {maps["armor"][0]}, "weapon": {maps["melee"][0]}, "horse": set()}
    equipment = json.load(open(os.path.join(PROJECT, "data", "items", "equipment.json"), encoding="utf-8"))
    for e in equipment:
        kind = {0: "melee", 1: "range", 2: "armor", 7: "helm", 10: "horse"}.get(e["detail"])
        res = maps[kind].get(e["particular"] * 10 + e["level"]) if kind else None
        if res is not None and res >= 0:
            out["weapon" if kind in ("melee", "range") else kind].add(res)
    gold = json.load(open(os.path.join(PROJECT, "data", "items", "gold_equipment.json"), encoding="utf-8"))
    gold_res = gold_res_map()
    for item in gold:
        group = {0: "weapon", 1: "weapon", 2: "armor", 7: "helm"}.get(item["detail"])
        if group and str(item.get("row", -1)) in gold_res:
            out[group].add(gold_res[str(item["row"])])
    out["weapon"] = {w for w in out["weapon"] if w < weapon_rows}
    return {k: sorted(v) for k, v in out.items()}


def gold_res_map():
    """GoldEquipRes.txt (KItemChangeRes::GetGoldItemRes): mã hình riêng của đồ hoàng kim, tra theo số hàng gốc + 1.
    Chỉ giữ vũ khí/áo/mũ -> {row: mã hình}."""
    rows = open(os.path.join(ITEM_SETTINGS, "GoldEquipRes.txt"), "rb").read().decode("gbk", "replace").splitlines()
    by_id = {}
    for line in rows[1:]:
        cols = line.split("\t")
        if len(cols) > 1 and cols[0].strip().isdigit() and cols[1].strip().lstrip("-").isdigit():
            by_id[int(cols[0])] = int(cols[1]) - 2
    gold = json.load(open(os.path.join(PROJECT, "data", "items", "gold_equipment.json"), encoding="utf-8"))
    out = {}
    for item in gold:
        if item["detail"] in (0, 1, 2, 7) and item.get("row", -1) + 1 in by_id:
            out[str(item["row"])] = by_id[item["row"] + 1]
    return out


## PNG nhân vật KHÔNG cho Godot nhập (importer "keep" = đóng gói nguyên file vào bản build): game tự đọc PNG bảng
## màu lúc chạy (AvatarData.get_texture) — bản build nhẹ hơn ~2,4 lần so với texture Godot nhập (RGBA), hình y hệt.
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def write_keep_import(png_path):
    imp = png_path + ".import"
    if not os.path.isfile(imp) or open(imp, encoding="utf-8").read() != KEEP_IMPORT:
        with open(imp, "w", encoding="utf-8", newline="\n") as fp:
            fp.write(KEEP_IMPORT)


def export_png(paks, spr_dir, spr_name, out_dir):
    """1 file .spr -> sheet PNG cắt sát (cột = frame/hướng, hàng = hướng). Trả về mô tả cho json, None nếu thiếu."""
    data = paks.read(spr_dir + "/" + spr_name)
    if data is None:
        return None
    tmp = os.path.join(out_dir, "_tmp.spr")
    open(tmp, "wb").write(data)
    try:
        images, meta = spr_to_png.read_spr(tmp)
    except Exception as e:  ## noqa: BLE001 — vài file trong pak gốc bị hỏng: bỏ qua, game lùi về không có lớp đó
        print("  bỏ qua file hỏng:", spr_name, e)
        return None
    finally:
        os.remove(tmp)
    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        return None
    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
    w, h = right - left, bottom - top
    dirs = max(meta["directions"], 1)
    per_dir = meta["frames"] // dirs
    sheet = Image.new("RGBA", (w * per_dir, h * dirs))
    for i, im in enumerate(images[:per_dir * dirs]):
        sheet.paste(im.crop((left, top, right, bottom)), ((i % per_dir) * w, (i // per_dir) * h))
    key = os.path.splitext(spr_name)[0].lower()
    ## Sprite gốc chỉ có <= 256 màu (+ vài mức trong suốt) -> lưu PNG bảng màu, nhẹ ~4 lần so với RGBA.
    sheet.quantize(256, method=Image.Quantize.FASTOCTREE).save(os.path.join(out_dir, key + ".png"), optimize=True)
    return key, {"frames_per_dir": per_dir, "dirs": dirs, "interval": max(meta["interval"], 1),
                 "size": [w, h], "offset": [left, top]}


def build(gender):
    prefix, spr_dir = GENDERS[gender]
    tables = Tables()
    paks = PakList(CLIENT)
    action_names = [r.strip() for r in tables.lines(TABLE_ACTION_ID + ".txt")[1:] if r.strip()]
    order = read_draw_order(tables, prefix)
    maps = item_res_maps()

    ## Bảng liên kết vũ khí -> bộ động tác (gộp các mã vũ khí cùng bộ để json gọn): đi bộ và cưỡi ngựa.
    def read_action_sets(table_name):
        hdr, rows = tables.tab(prefix + table_name + ".txt")
        sets, per_weapon = [], []
        for row in rows:
            entry = {k: row[hdr.index(col)] for k, col in WEAPON_ACTION_COLUMNS.items()}
            if not entry["stand"]:
                per_weapon.append(-1)
                continue
            if entry not in sets:
                sets.append(entry)
            per_weapon.append(sets.index(entry))
        return sets, per_weapon, len(rows)

    action_sets, weapon_action_set, weapon_rows = read_action_sets(TABLE_WEAPON_ACTIONS)
    ride_action_sets, weapon_ride_action_set, _ = read_action_sets(TABLE_RIDE_ACTIONS)
    auto = _auto_export(maps, weapon_rows)
    export = {k: (v if v is not None else auto[k]) for k, v in EXPORT.items()}

    ## Động tác cần xuất: bộ đi bộ của các vũ khí trong đợt + bộ cưỡi ngựa (nếu đợt có ngựa).
    def actions_of(sets, per_weapon, weapons):
        ids = {per_weapon[w] for w in weapons if w < len(per_weapon) and per_weapon[w] >= 0}
        return {sets[i][k] for i in ids for k in USED_ACTIONS if sets[i].get(k)}

    walk_actions = actions_of(action_sets, weapon_action_set, export["weapon"])
    ride_actions = actions_of(ride_action_sets, weapon_ride_action_set, export["weapon"]) if export["horse"] else set()
    needed_actions = sorted(walk_actions | ride_actions)
    out_dir = os.path.join(PROJECT, "assets", "avatar", gender)
    os.makedirs(out_dir, exist_ok=True)
    files, sprites = {}, {}
    out_json = os.path.join(PROJECT, "data", "avatar", gender + ".json")
    previous = {}
    if os.path.isfile(out_json):
        previous = json.load(open(out_json, encoding="utf-8")).get("files", {})
    ## Bộ nhớ đệm từng phần (ghi mỗi 50 file) — lần chạy bị ngắt giữa chừng vẫn dùng lại được file đã xuất.
    cache_path = os.path.join(out_dir, "_cache.json")
    if os.path.isfile(cache_path):
        previous.update(json.load(open(cache_path, encoding="utf-8")))
    new_count = [0]

    def add(part, res, action, spr_name):
        if not spr_name:
            return
        key = os.path.splitext(spr_name)[0].lower()
        if key not in files:
            if key in previous and os.path.isfile(os.path.join(out_dir, key + ".png")):
                files[key] = previous[key]
            else:
                got = export_png(paks, spr_dir, spr_name, out_dir)
                files[key] = got[1] if got else None
                new_count[0] += 1
                if new_count[0] % 50 == 0:
                    with open(cache_path, "w", encoding="utf-8") as fp:
                        json.dump({k: v for k, v in files.items() if v is not None}, fp)
        if files[key] is not None:
            sprites.setdefault(part, {}).setdefault(str(res), {})[action] = key

    for group, parts in GROUPS.items():
        for part in parts:
            hdr, rows = tables.tab(prefix + PARTS[part][1] + ".txt")
            for res in export[group]:
                if res >= len(rows):
                    continue
                actions = needed_actions
                if group == "weapon":
                    ## Vũ khí chỉ cần bộ động tác của chính nó (đi bộ + cưỡi ngựa).
                    actions = sorted(actions_of(action_sets, weapon_action_set, [res])
                                     | (actions_of(ride_action_sets, weapon_ride_action_set, [res])
                                        if export["horse"] else set()))
                elif group == "horse":
                    actions = sorted(ride_actions)
                for action in actions:
                    col = action_names.index(action) + 1
                    add(part, res, action, rows[res][col] if col < len(rows[res]) else "")
            print("xong", part, len(sprites.get(part, {})), "mã hình")
    ## Bóng: hàng đầu = nam, hàng 2 = nữ.
    hdr, rows = tables.tab(TABLE_SHADOW + ".txt")
    shadow = {}
    srow = rows[0 if gender == "male" else 1]
    for action in needed_actions:
        if action in hdr:
            name = srow[hdr.index(action)].strip('"')
            if name:
                add("shadow", 0, action, name)
    shadow = sprites.pop("shadow", {}).get("0", {})

    ## Điểm neo (chân nhân vật) = tâm vết bóng lúc đứng, hướng 0.
    anchor = [160, 200]
    stand = action_sets[weapon_action_set[0]]["stand"]
    if stand in shadow:
        f = files[shadow[stand]]
        img = Image.open(os.path.join(out_dir, shadow[stand] + ".png")).crop((0, 0, f["size"][0], f["size"][1]))
        box = img.getbbox()
        if box:
            anchor = [f["offset"][0] + (box[0] + box[2]) // 2, f["offset"][1] + (box[1] + box[3]) // 2]

    data = {
        "gender": gender,
        "canvas": [320, 320],
        "anchor": anchor,
        "fps": 18,
        "png_dir": "res://assets/avatar/%s/" % gender,
        "layer_ids": {k: v[0] for k, v in PARTS.items()},
        "groups": GROUPS,
        "action_sets": action_sets,
        "weapon_action_set": weapon_action_set,
        "ride_action_sets": ride_action_sets,
        "weapon_ride_action_set": weapon_ride_action_set,
        "gold_res": gold_res_map(),
        "item_res": {k: {str(kk): vv for kk, vv in v.items()} for k, v in maps.items()},
        "draw_order": {a: resolve_order(order, a) for a in needed_actions},
        "shadow": shadow,
        "sprites": sprites,
        "files": {k: v for k, v in files.items() if v is not None},
        ## Chỉ tính là "đã xuất" khi bộ phận chính thật sự có hình (vài mã không có sprite cho giới tính này) —
        ## mã không có thì game lùi về hình gần nhất thay vì mất hẳn lớp.
        "exported": {g: [r for r in export[g] if any(str(r) in sprites.get(part, {}) for part in MAIN_PART[g])]
                     for g in export},
    }
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    if os.path.isfile(cache_path):
        os.remove(cache_path)
    keep = {k + ".png" for k in data["files"]}
    for name in keep:
        write_keep_import(os.path.join(out_dir, name))
    for name in os.listdir(out_dir):
        if name.endswith(".png") and name not in keep:
            os.remove(os.path.join(out_dir, name))
            if os.path.isfile(os.path.join(out_dir, name + ".import")):
                os.remove(os.path.join(out_dir, name + ".import"))
    with open(out_json, "w", encoding="utf-8") as fp:
        json.dump(data, fp, ensure_ascii=False, separators=(",", ":"))
    total = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir) if f.endswith(".png"))
    print("đợt hình:", export)
    print("động tác:", needed_actions)
    print("PNG: %d file, %.1f MB; json %.1f KB" % (len(data["files"]), total / 1e6, os.path.getsize(out_json) / 1e3))


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "male")
