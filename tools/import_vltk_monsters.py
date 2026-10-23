"""Nhập TẤT CẢ QUÁI VLTK gốc: thông số, AI, skill, và hình ảnh mọi động tác (đứng, đi, chạy, bị đánh, chết, đánh, phép).

    python tools/import_vltk_monsters.py             # nhập hết
    python tools/import_vltk_monsters.py --limit 20  # thử với 20 bộ tài nguyên đầu

Nguồn (không đoán):
  - server settings/Npcs.txt (TCVN5712-1): mỗi dòng 1 mẫu NPC — Kind 0 = quái. Cột: Name, Series (ngũ hành), Camp,
    NpcResType (tên bộ tài nguyên hình), Skill1-4 + Level1-4, StandFrame/WalkFrame/RunFrame/DeathFrame/HurtFrame (số frame
    mỗi động tác), WalkSpeed/RunSpeed/AttackSpeed/CastSpeed, VisionRadius/ActiveRadius, AIMode + AIParam1-9 + AIMaxTime,
    kháng tối đa, Stature...
  - client settings/npcres/普通npc资源.txt (tên bộ -> file .spr mỗi động tác) và 普通npc资源信息.txt ("số frame,số hướng,nhịp")
    + 人物类型.txt (thư mục chứa .spr của bộ tài nguyên).
  - client pak: file .spr -> PNG.

Đầu ra:
  data/monsters/monsters.json    {STT: {...thông số...}}   — chỉ quái có bộ tài nguyên hình
  data/monsters/resources.json   {tên bộ: {động tác: {anim, frames, dirs, interval}}}
  data/monsters/anims.json       {key: {cols, frames, dirs, interval, size, offset}}  offset = góc trên-trái so với TÂM sprite
  assets/monster/<key>.png       sheet (frame thứ i ở ô (i % cols, i / cols); i = hướng * frame_mỗi_hướng + frame) + .import "keep"
Skill của quái được nhập bằng: python tools/import_vltk_skill_fx.py --monsters
"""
import io
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import spr_to_png  # noqa: E402
from import_vltk_avatar import Tables, write_keep_import, CLIENT  # noqa: E402
from vltk_pak import PakList  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SERVER = Path("D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server")
NPCS_TXT = SERVER / "settings/Npcs.txt"
OUT_DATA = ROOT / "data/monsters"
OUT_PNG = ROOT / "assets/monster"
MAX_SHEET_WIDTH = 8192

## Thứ tự cột bảng tài nguyên (hàng tiêu đề tiếng Trung): tên động tác trong game.
ACTIONS = ["fight_stand", "stand1", "stand2", "fight_walk", "walk", "fight_run", "run", "hurt", "die", "attack1",
           "attack2", "magic", "sit", "jump"]

_paks = None


def _init_worker():
    global _paks
    _paks = PakList(CLIENT)


def to_int(text, default=0):
    try:
        return int(float(str(text).strip()))
    except ValueError:
        return default


def export_sheet(task):
    """task = (key, đường dẫn trong pak). Trả về (key, mô tả | None)."""
    key, path = task
    out = OUT_PNG / (key + ".png")
    data = _paks.read(path)
    if data is None:
        return key, None
    fd, tmp = tempfile.mkstemp(suffix=".spr")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    try:
        images, meta = spr_to_png.read_spr(tmp)
    except Exception as e:  # noqa: BLE001 — vài .spr trong pak gốc hỏng: bỏ qua
        return key, {"error": str(e)}
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        return key, None
    ## File SPR gốc của enemy177_wlk lưu frame của mỗi hướng bị ngược (10..0 thay vì 0..10), khiến quái đi lùi (moonwalk).
    if key == "enemy177_enemy177_wlk":
        dirs = max(meta["directions"], 1)
        per_dir = len(images) // dirs
        new_images = []
        for d in range(dirs):
            new_images.extend(reversed(images[d * per_dir : (d + 1) * per_dir]))
        images = new_images
    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
    w, h = right - left, bottom - top
    count = len(images)
    cols = max(1, min(count, MAX_SHEET_WIDTH // max(w, 1)))
    rows = (count + cols - 1) // cols
    sheet = Image.new("RGBA", (w * cols, h * rows))
    for i, im in enumerate(images):
        sheet.paste(im.crop((left, top, right, bottom)), ((i % cols) * w, (i // cols) * h))
    ## Sprite gốc chỉ có <= 256 màu (+ vài mức trong suốt) -> PNG bảng màu, nhẹ ~4 lần so với RGBA.
    sheet.quantize(256, method=Image.Quantize.FASTOCTREE).save(out, optimize=True)
    write_keep_import(str(out))
    cx, cy = meta["center"]
    if cx == 0 and cy == 0 and meta["frame_width"] > 160:
        cx, cy = 160, 192
    return key, {"cols": cols, "frames": count, "dirs": max(meta["directions"], 1),
                 "interval": max(meta["interval"], 1), "size": [w, h], "offset": [left - cx, top - cy]}


def read_npcs():
    raw = NPCS_TXT.read_bytes()
    text = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=raw,
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")
    lines = text.split("\n")
    header = [h.strip() for h in lines[0].split("\t")]
    return [dict(zip(header, l.rstrip("\r").split("\t"))) for l in lines[1:] if l.strip()]


def parse_info(text):
    parts = [to_int(p, -1) for p in text.replace('"', "").split(",")]
    parts += [-1] * 3
    return parts[0] if parts[0] > 0 else 16, parts[1] if parts[1] > 0 else 8, parts[2] if parts[2] >= 0 else 0


def main():
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else 0
    OUT_DATA.mkdir(parents=True, exist_ok=True)
    OUT_PNG.mkdir(parents=True, exist_ok=True)
    tables = Tables()
    folders, table, info = {}, {}, {}
    for line in tables.lines("\u4eba\u7269\u7c7b\u578b.txt")[1:]:
        c = line.split("\t")
        if len(c) > 2 and c[1] == "NormalNpc":
            folders[c[0].strip()] = c[2].strip()
    for line in tables.lines("\u666e\u901anpc\u8d44\u6e90.txt")[1:]:
        c = line.split("\t")
        table[c[0].strip()] = c[1:]
    for line in tables.lines("\u666e\u901anpc\u8d44\u6e90\u4fe1\u606f.txt")[1:]:
        c = line.split("\t")
        info[c[0].strip()] = c[1:]

    rows = [r for r in read_npcs() if r.get("Kind", "").strip() == "0" and r.get("NpcResType", "").strip() in table
            and r["NpcResType"].strip() in folders]
    resources = sorted({r["NpcResType"].strip() for r in rows})
    if limit:
        resources = resources[:limit]
        rows = [r for r in rows if r["NpcResType"].strip() in resources]
    print("quái:", len(rows), "| bộ tài nguyên:", len(resources))

    tasks, res_actions = {}, {}
    for res in resources:
        acts = {}
        cells, infos = table[res], info.get(res, [])
        for i, action in enumerate(ACTIONS):
            fname = cells[i].strip() if i < len(cells) else ""
            if not fname:
                continue
            key = (res + "_" + os.path.splitext(fname)[0]).lower()
            tasks[key] = "\\" + folders[res] + "\\" + fname
            ## Bóng gốc (KNpcResNode::GetShadowName): cùng tên + "b" (enemy003_st.spr -> enemy003_stb.spr), cùng số frame/hướng.
            tasks[key + "b"] = "\\" + folders[res] + "\\" + os.path.splitext(fname)[0] + "b.spr"
            frames, dirs, interval = parse_info(infos[i]) if i < len(infos) else (16, 8, 0)
            acts[action] = {"anim": key, "table_frames": frames, "table_dirs": dirs, "table_interval": interval}
        res_actions[res] = acts

    anims_path = OUT_DATA / "anims.json"
    anims = json.loads(anims_path.read_text(encoding="utf-8")) if anims_path.exists() else {}
    todo = [(k, p) for k, p in tasks.items() if k not in anims]
    print("sheet cần xuất:", len(todo), "(đã có", len(tasks) - len(todo), ")")
    workers = max(1, (os.cpu_count() or 2) - 1)
    done = 0
    with ProcessPoolExecutor(max_workers=workers, initializer=_init_worker) as pool:
        for key, desc in pool.map(export_sheet, todo, chunksize=2):
            done += 1
            if desc and "error" not in desc:
                anims[key] = desc
            elif desc:
                print("  bỏ qua file hỏng:", key, desc["error"])
            if done % 50 == 0:
                print("  ", done, "/", len(todo), flush=True)
                anims_path.write_text(json.dumps(anims, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    anims_path.write_text(json.dumps(anims, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")

    ## Bộ tài nguyên: chỉ giữ động tác có hình thật; số frame/hướng/nhịp theo bảng thông tin (KNpcResNode gốc), thiếu thì theo .spr.
    resources_out = {}
    for res, acts in res_actions.items():
        out = {}
        for action, a in acts.items():
            meta = anims.get(a["anim"])
            if not meta:
                continue
            frames = a["table_frames"] if a["table_frames"] <= meta["frames"] else meta["frames"]
            out[action] = {"anim": a["anim"], "frames": meta["frames"] if a["table_frames"] <= 0 else frames,
                           "dirs": a["table_dirs"] or meta["dirs"], "interval": a["table_interval"] or meta["interval"]}
            if a["anim"] + "b" in anims:
                out[action]["shadow"] = a["anim"] + "b"
        if out:
            resources_out[res] = out
    (OUT_DATA / "resources.json").write_text(json.dumps(resources_out, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")

    monsters = {}
    for r in rows:
        res = r["NpcResType"].strip()
        if res not in resources_out:
            continue
        monsters[r["STT"].strip()] = {
            "name": r["Name"].strip(), "res": res, "series": to_int(r.get("Series", "0")), "camp": to_int(r.get("Camp", "5")),
            "frames": {"stand": to_int(r["StandFrame"]), "stand1": to_int(r["StandFrame1"]), "death": to_int(r["DeathFrame"]),
                       "walk": to_int(r["WalkFrame"]), "run": to_int(r["RunFrame"]), "hurt": to_int(r["HurtFrame"])},
            "skills": [[to_int(r.get("Skill%d" % i, "0")), max(1, to_int(r.get("Level%d" % i, "1"), 1))] for i in range(1, 5)],
            "walk_speed": to_int(r["WalkSpeed"]), "run_speed": to_int(r["RunSpeed"]),
            "attack_speed": to_int(r["AttackSpeed"]), "cast_speed": to_int(r["CastSpeed"]),
            "vision": to_int(r["VisionRadius"]), "active": to_int(r["ActiveRadius"]), "hit_recover": to_int(r["HitRecover"]),
            "ai_mode": to_int(r["AIMode"]), "ai_params": [to_int(r.get("AIParam%d" % i, "0")) for i in range(1, 10)],
            "ai_max_time": max(1, to_int(r.get("AIMaxTime", "10"), 10)), "stature": to_int(r.get("Stature", "100"), 100),
            "resist_max": [to_int(r.get(k + "ResistMax", "0")) for k in ("Fire", "Cold", "Light", "Poison", "Physics")],
            "revive_frame": to_int(r.get("ReviveFrame", "0")),
            "life_param": to_int(r.get("LifeParam", "100"), 100), "exp_param": to_int(r.get("ExpParam", "100"), 100),
            "min_damage_param": to_int(r.get("MinDamageParam", "100"), 100),
            "max_damage_param": to_int(r.get("MaxDamageParam", "100"), 100),
            "defense_param": to_int(r.get("DefenseParam", "100"), 100),
        }
    (OUT_DATA / "monsters.json").write_text(json.dumps(monsters, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print("xong: quái", len(monsters), "| bộ tài nguyên", len(resources_out), "| sheet", len(anims))


if __name__ == "__main__":
    main()
