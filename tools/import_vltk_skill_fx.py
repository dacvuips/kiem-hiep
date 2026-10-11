"""Nhập CƠ CHẾ + HÌNH ẢNH chiêu thức VLTK gốc (đạn bay, nổ, trúng đòn, ảnh xuất chiêu) cho bộ máy chiêu
systems/skill_fx (VltkSkillRunner / VltkMissile).

    python tools/import_vltk_skill_fx.py [phái ...]      # mặc định: nga_mi (đợt thử nghiệm)
    python tools/import_vltk_skill_fx.py --all            # cả 10 phái
    python tools/import_vltk_skill_fx.py --monsters       # skill + đạn của mọi quái (cần chạy import_vltk_monsters.py trước)

Nguồn (không đoán số):
  - server settings/Skills.txt: mỗi skill -> đội hình đạn (MisslesForm), số đạn (ChildSkillNum), skill con/đạn con
    (ChildSkillId + BaseSkill), Param1/2, WaitTime, cách sinh đạn (MslsGenerate/MslsGenerateData), sự kiện
    Start/Fly/Collide/Vanished, ảnh xuất chiêu PreCastSpr... (KSkill::GetInfoFromTabFile).
  - script/skill/<phái>.lua: giá trị theo cấp của các thuộc tính skill_* / missle_* (KSkill::LoadSkillLevelData ->
    GetSkillLevelData = Link() nội suy các mốc, floor) — VD số đạn, tốc độ đạn, tầm đánh tăng theo cấp.
  - server settings/Missles.txt: đạn -> kiểu bay (MoveKind), tốc độ, thời gian sống, tầm va chạm, vùng sát thương,
    xuyên/biến mất khi trúng, 4 ảnh theo giai đoạn (chờ/bay/va chạm/biến mất) + bộ B (MultiShow), AnimFileInfo
    "số frame, số hướng, nhịp" (KMissle::GetInfoFromTabFile).
  - client pak: file .spr -> PNG.

Đầu ra (key tiếng Anh/số, không giữ chữ Hán):
  data/skill_fx/skills.json    {SkillId: {...}} — gồm skill người chơi của phái + mọi skill con/skill sự kiện.
  data/skill_fx/missiles.json  {MissleId: {...}}
  data/skill_fx/anims.json     {key ảnh: {cols, frames, dirs, interval, size, offset}} — offset = góc trên trái
                               ảnh so với TÂM sprite gốc (KSprite vẽ tại vị trí - tâm).
  assets/skill_fx/<key>.png    sheet (frame thứ i ở ô (i % cols, i / cols), thứ tự frame như .spr gốc) + .import
                               "keep" (game tự đọc PNG như ảnh nhân vật).
"""
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from vltk_pak import PakList, file_name_to_id, normalize  # noqa: E402
import spr_to_png  # noqa: E402
import vltk_pak  # noqa: E402
import import_vltk_hit_effects as hit  # noqa: E402  (parser bảng lua)
from import_vltk_avatar import write_keep_import, CLIENT, Tables  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
## Chỗ bản server THẬT (server-vm, máy ảo) khác bảng client VNG và người dùng xác nhận chạy đúng/mạnh hơn:
##   Vô Hình Độc: skill 69 tầm 100 (VNG 200); skill 203 (hào quang gây độc) ở server bắn đạn 94 (vùng sát thương 8 ô), client VNG đổi sang đạn 451 (chỉ 5 ô).
SERVER_OVERRIDES = {203: {"child": 94}, 69: {"attack_radius": 100}}
## Nguồn chuẩn: client VNG (bản mới nhất) — Skills.txt, Missles.txt, script/skill/*.lua và sprite đều đọc thẳng từ pak của nó.
## Bản Anh-Việt cũ thiếu nhiều skill/đạn (441 đạn so với 737 của VNG) nên chỉ còn làm nguồn dự phòng cho file không có trong VNG.
VNG_CLIENT = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
VNG_PAK_ORDER = "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split()


class _Paks:
    """Đọc file theo thứ tự: pak VNG trước (pak nạp sau thắng, giống bản vá đè), rồi client cũ nếu VNG không có."""

    def __init__(self):
        self.vng = PakList.__new__(PakList)
        self.vng.client_dir, self.vng.paks = VNG_CLIENT, []
        for n in VNG_PAK_ORDER:
            f = os.path.join(VNG_CLIENT, "data", n + ".pak")
            if os.path.isfile(f):
                self.vng.paks.append(vltk_pak.PakFile(f))
        self.old = PakList(CLIENT)

    def read(self, path):
        data = self.vng.read(path)
        return data if data is not None else self.old.read(path)


def _extract_vng(paks):
    """Giải nén Skills.txt, Missles.txt và mọi script lua theo cấp mà Skills.txt nhắc tới ra thư mục tạm (hit.LUA_DIRS đọc theo thư mục)."""
    out = Path(tempfile.mkdtemp(prefix="vng_skillfx_"))
    (out / "settings").mkdir()
    for name in ("Skills.txt", "Missles.txt"):
        data = paks.vng.read("settings/" + name)
        if data is None:
            raise SystemExit("Không thấy settings/%s trong pak VNG" % name)
        (out / "settings" / name).write_bytes(data)
    scripts = set()
    for line in (out / "settings/Skills.txt").read_bytes().split(b"\n")[1:]:
        for cell in line.split(b"\t"):
            c = cell.decode("gbk", "replace").strip()
            if c.lower().endswith(".lua"):
                scripts.add(c.replace("\\", "/").lstrip("/"))
    got = 0
    for sc in sorted(scripts):
        try:
            data = paks.vng.read(sc)
        except UnicodeEncodeError:
            continue
        if data is not None:
            dest = out / sc
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            got += 1
    print("VNG: %d/%d script lua theo cấp" % (got, len(scripts)))
    return out


_PAKS = _Paks()
SERVER = _extract_vng(_PAKS)
SKILLS_TXT = SERVER / "settings/Skills.txt"
MISSLES_TXT = SERVER / "settings/Missles.txt"
TRES_DIR = ROOT / "systems/sect/data"
OUT_DATA = ROOT / "data/skill_fx"
OUT_PNG = ROOT / "assets/skill_fx"
## Lua theo cấp ưu tiên lấy từ server (đúng bản đang chạy), không có mới tìm ở client.
hit.LUA_DIRS.insert(0, SERVER)

ALL_SECTS = ["thieu_lam", "thien_vuong_bang", "duong_mon", "ngu_doc_giao", "nga_mi", "thuy_yen_mon", "cai_bang",
             "thien_nhan_giao", "vo_dang", "con_lon"]
## Cấp tính sẵn giá trị theo cấp (skill người chơi tối đa 20, đồ +kỹ năng/skill sự kiện có thể vượt).
MAX_LEVEL = 30
SKILL_INT_COLUMNS = {
    "style": "SkillStyle", "form": "MisslesForm", "child": "ChildSkillId", "child_num": "ChildSkillNum",
    "child_level": "ChildSkillLevel", "base": "BaseSkill", "param1": "Param1", "param2": "Param2",
    "wait": "WaitTime", "gen_style": "MslsGenerate", "gen_data": "MslsGenerateData", "melee": "IsMelee",
    "by_missle": "ByMissle", "heel": "HeelAtParent", "stop_when_move": "StopWhenMove",
    "attack_radius": "AttackRadius", "char_anim": "CharAnimId", "time_per_cast": "TimePerCast",
    "event_level": "EventSkillLevel", "target_self": "TargetSelf", "target_enemy": "TargetEnemy",
    "target_ally": "TargetAlly", "aura": "IsAura", "physical": "IsPhysical", "series": "Series",
    "start_event": "StartEvent", "start_skill": "StartSkillId", "fly_event": "FlyEvent", "fly_skill": "FlySkillId",
    "fly_time": "FlyEventTime", "collide_event": "CollideEvent", "collide_skill": "CollidSkillId",
    "vanish_event": "VanishedEvent", "vanish_skill": "VanishedSkillId", "need_shadow": "NeedShadow",
    "max_shadow": "MaxShadowNum", "state": "StateSpecialId",
    "use_ar": "IsUseAR", "do_hurt": "DoHurt",   ## IsUseAR = 0 -> đòn KHÔNG tính trúng/trượt (KNpc::ReceiveDamage bUseAR); DoHurt = % khựng
}
SKILL_DEFAULTS = {"attack_radius": 50, "series": -1, "do_hurt": 1}   ## DoHurt mặc định 1 (KSkill ctor gốc)
MISSLE_INT_COLUMNS = {
    "move_kind": "MoveKind", "follow_kind": "FollowKind", "col_follow": "ColFollowTarget", "height": "MissleHeight",
    "collide_range": "CollidRange", "range_dmg": "IsRangeDmg", "dmg_range": "DmgRange", "dmg_interval": "DmgInterval",
    "life": "LifeTime", "speed": "Speed", "zspeed": "Zspeed", "zacc": "Zacc", "loop": "LoopPlay",
    "sub_loop": "SubLoop", "sub_start": "SubStart", "sub_stop": "SubStop", "col_vanish": "ColVanish",
    "col_friend": "CanColFriend", "auto_explode": "AutoExplode", "miss_rate": "MissRate", "param1": "Param1",
    "param2": "Param2", "param3": "Param3", "multi_show": "MultiShow",
}
## Thuộc tính theo cấp liên quan cơ chế chiêu (KSkill::ParseString2MagicAttrib nhánh magic_skill_* / magic_missle_*).
LEVEL_ATTR_PREFIXES = ("skill_", "missle_")
## Thuộc tính sát thương/hiệu ứng nguyên tố của skill (không có tiền tố skill_/missle_) — quái dùng để đánh theo hệ.
HIT_LEVEL_ATTRS = ("physicsenhance_p", "physicsdamage_v", "colddamage_v", "firedamage_v", "lightingdamage_v",
                   "poisondamage_v", "magicdamage_v", "stun_p", "deadlystrike_p", "fatallystrike_p", "seriesdamage_p",
                   "attackrating_p", "ignoredefense_p")
LEVEL_ATTR_SKIP = {"skill_desc", "skill_skillexp_v", "skill_cost_v", "skill_costtype_v", "skill_enhance"}
EVENT_ATTRS = ("skill_startevent", "skill_flyevent", "skill_collideevent", "skill_vanishedevent")
MAX_SHEET_WIDTH = 8192


def to_int(text, default=0):
    try:
        return int(float(text.strip()))
    except (ValueError, AttributeError):
        return default


def read_table(path):
    """[(cột -> chuỗi UTF-8 (tên tiếng Việt TCVN), cột -> chuỗi GBK (đường dẫn file))]."""
    raw_lines = path.read_bytes().split(b"\n")
    viet = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace").split("\n")
    header = raw_lines[0].rstrip(b"\r").decode("latin1").split("\t")
    rows = []
    for raw, text in zip(raw_lines[1:], viet[1:]):
        if not raw.strip():
            continue
        cells = raw.rstrip(b"\r").split(b"\t")
        vcells = text.rstrip("\r").split("\t")
        row_viet = {h: (vcells[i].strip() if i < len(vcells) else "") for i, h in enumerate(header)}
        row_gbk = {h: (cells[i].decode("gbk", "replace").strip() if i < len(cells) else "") for i, h in enumerate(header)}
        rows.append((row_viet, row_gbk))
    return header, rows


# ---- giá trị theo cấp: Link()/Line/Conic/Extrac nguyên văn script/skill/*.lua ----
def _line(x, x1, y1, x2, y2):
    return y2 if x2 == x1 else (y2 - y1) * (x - x1) / (x2 - x1) + y1


def _conic(x, x1, y1, x2, y2):
    if x1 < 0 or x2 < 0:
        return 0
    if x2 == x1:
        return y2
    return (y2 - y1) * x * x / (x2 * x2 - x1 * x1) - (y2 - y1) * x1 * x1 / (x2 * x2 - x1 * x1) + y1


def _extrac(x, x1, y1, x2, y2):
    if x1 < 0 or x2 < 0:
        return 0
    return y2 if x2 == x1 else (y2 - y1) * (x - x1) / (x2 - x1) + y1


CURVES = {"Line": _line, "Conic": _conic, "Extrac": _extrac}


def link(x, points):
    pts = [p for p in (points or []) if isinstance(p, list) and len(p) >= 2]
    if len(pts) < 2:
        return -1 if pts or points else 0
    fn = lambda p: CURVES.get(p[2], _line) if len(p) > 2 and isinstance(p[2], str) else _line  # noqa: E731
    if x < pts[0][0]:
        return fn(pts[0])(x, pts[0][0], pts[0][1], pts[1][0], pts[1][1])
    if x > pts[-1][0]:
        return fn(pts[-1])(x, pts[-2][0], pts[-2][1], pts[-1][0], pts[-1][1])
    c = 1
    for i in range(1, len(pts)):
        if pts[i - 1][0] <= x <= pts[i][0]:
            c = i
            break
    return fn(pts[c])(x, pts[c - 1][0], pts[c - 1][1], pts[c][0], pts[c][1])


def level_values(script, table, attr):
    """[[v1, v2, v3] cho cấp 1..MAX_LEVEL] hoặc None (thuộc tính dạng hàm lua / không có)."""
    comps = hit.lua_attr(script, table, attr)
    if comps is None:
        return None
    comps = (list(comps) + [None, None, None])[:3]
    out = []
    for lv in range(1, MAX_LEVEL + 1):
        out.append([int(math.floor(link(lv, c))) if c else 0 for c in comps])
    return out


# ---- skill ----
def viet_name(viet, gbk, col):
    """Tên tiếng Việt (TCVN luôn có chữ cái ASCII); tên gốc tiếng Trung (GBK — toàn byte >= 0x80, không có chữ cái
    ASCII nào) -> "" (main() đặt lại theo skill cha)."""
    return viet.get(col, "") if re.search(r"[A-Za-z]", gbk.get(col, "")) else ""


def build_skill(viet, gbk):
    s = {"name": viet_name(viet, gbk, "SkillName")}
    for key, col in SKILL_INT_COLUMNS.items():
        s[key] = to_int(viet.get(col, ""), SKILL_DEFAULTS.get(key, 0))
    s["precast"] = gbk.get("PreCastSpr", "")
    script = gbk.get("LvlSetScript", "").replace("\\", "/").lstrip("/")
    levels = {}
    n = 1
    while f"LvlSetting{n}" in viet:
        attr = viet[f"LvlSetting{n}"].strip()
        table = viet.get(f"LvlData{n}", "").strip()
        n += 1
        if not attr or not table or table == "0" or attr in LEVEL_ATTR_SKIP                 or not (attr.startswith(LEVEL_ATTR_PREFIXES) or attr in HIT_LEVEL_ATTRS):
            continue
        values = level_values(script, table, attr)
        if values is not None:
            levels[attr] = values
    s["levels"] = levels
    return s


def referenced_skills(s):
    """SkillId các skill con / skill sự kiện (cột + thuộc tính theo cấp, giá trị thứ 3 = SkillId)."""
    out = set()
    if s["base"] == 0 and s["child"] > 0:
        out.add(s["child"])
    for flag, col in (("start_event", "start_skill"), ("fly_event", "fly_skill"), ("collide_event", "collide_skill"),
                      ("vanish_event", "vanish_skill")):
        if s[flag] and s[col] > 0:
            out.add(s[col])
    for attr in EVENT_ATTRS:
        for v in s["levels"].get(attr, []):
            if v[0] and v[2] > 0:
                out.add(v[2])
    return out


def sect_root_skills(sects):
    ids = []
    for sect in sects:
        text = (TRES_DIR / f"{sect}.tres").read_text(encoding="utf-8")
        for block in re.split(r"(?=\n\[sub_resource)", text):
            m = re.search(r"^vltk_skill_id = (\d+)", block, re.M)
            if m and not re.search(r"^is_hidden = true", block, re.M):
                ids.append(int(m.group(1)))
    return ids


# ---- ảnh ----
def anim_key(path):
    base = os.path.splitext(os.path.basename(normalize(path).replace("\\", "/")))[0].lower()
    if re.fullmatch(r"[a-z0-9_\-]+", base):
        return re.sub(r"[^a-z0-9_]", "_", base) + "_%04x" % (file_name_to_id(normalize(path)) & 0xFFFF)
    return "fx_%08x" % file_name_to_id(normalize(path))


def export_anim(paks, path, cache):
    """1 file .spr -> assets/skill_fx/<key>.png. Trả về key (None nếu thiếu/hỏng)."""
    if not path or path == "0":
        return None
    key = anim_key(path)
    if key in cache:
        return key if cache[key] else None
    cache[key] = None
    data = paks.read(path)
    if data is None:
        print("  thiếu ảnh:", path)
        return None
    fd, tmp_name = tempfile.mkstemp(suffix=".spr")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    try:
        images, meta = spr_to_png.read_spr(tmp_name)
    except Exception as e:  # noqa: BLE001 — vài .spr trong pak gốc hỏng: bỏ qua, game không vẽ giai đoạn đó
        print("  bỏ qua ảnh hỏng:", path, e)
        return None
    finally:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        return None
    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
    w, h = right - left, bottom - top
    count = len(images)
    cols = max(1, min(count, MAX_SHEET_WIDTH // max(w, 1)))
    rows = (count + cols - 1) // cols
    sheet = Image.new("RGBA", (w * cols, h * rows))
    for i, im in enumerate(images):
        sheet.paste(im.crop((left, top, right, bottom)), ((i % cols) * w, (i // cols) * h))
    out = OUT_PNG / f"{key}.png"
    additive = luma_key_if_additive(sheet)
    sheet.save(out, optimize=True)
    write_keep_import(str(out))
    cx, cy = meta["center"]
    ## KRepresentShell2 (RUIMAGE_RENDER_FLAG_REF_SPOT): tâm (0, 0) mà ảnh rộng hơn 160 thì dùng tâm mặc định (160, 192).
    if cx == 0 and cy == 0 and meta["frame_width"] > 160:
        cx, cy = 160, 192
    cache[key] = {"cols": cols, "frames": count, "dirs": meta["directions"], "interval": max(meta["interval"], 1),
                  "size": [w, h], "offset": [left - cx, top - cy], "additive": additive}
    return key


## Ảnh vẽ cho hoà trộn CỘNG SÁNG (chủ yếu skill 150 thêm sau: Băng Vũ Lạc Tinh, kiếm Kiếm Hoa Vãn Tinh...): pixel đặc
## (alpha 255) mà tối = "không có gì" — vẽ alpha thường sẽ ra nền/viền đen. Nhận biết: >= 5% số pixel có hình là đặc
## và gần đen (ảnh hiệu ứng thường của bản gốc ~0%).
ADDITIVE_DARK_RATIO = 0.05
ADDITIVE_DARK_LEVEL = 48


def luma_key_if_additive(sheet):
    """Ảnh cộng sáng -> đổi độ sáng thành độ trong suốt (alpha × kênh màu lớn nhất, màu chia lại): vẽ alpha
    thường cho kết quả ~ cộng sáng mà vẫn giữ màu trên nền sáng. Trả về True nếu đã đổi."""
    data = sheet.get_flattened_data()
    shown = solid_dark = 0
    for r, g, b, a in data:
        if a:
            shown += 1
            if a == 255 and max(r, g, b) < ADDITIVE_DARK_LEVEL:
                solid_dark += 1
    if not shown or solid_dark / shown < ADDITIVE_DARK_RATIO:
        return False
    out = []
    for r, g, b, a in data:
        m = max(r, g, b)
        ## alpha mới = alpha gốc × độ sáng (cả viền bán trong suốt tối cũng biến mất như khi cộng sáng).
        out.append((r * 255 // m, g * 255 // m, b * 255 // m, a * m // 255) if m and a else (0, 0, 0, 0))
    sheet.putdata(out)
    return True


def parse_anim_info(text):
    """AnimFileInfo "số frame, số hướng, nhịp" (KSG_StringGetInt mặc định 100, 16, 1)."""
    nums = [to_int(x, -1) for x in re.split(r"[,\s]+", text.strip()) if x.strip()]
    nums += [-1] * 3
    defaults = [100, 16, 1]
    return [n if n >= 0 else d for n, d in zip(nums[:3], defaults)]


def build_missile(viet, gbk, paks, anim_cache):
    m = {"name": viet_name(viet, gbk, "MissleName")}
    for key, col in MISSLE_INT_COLUMNS.items():
        m[key] = to_int(viet.get(col, ""))
    for prefix, field in (("AnimFile", "anims"), ("AnimFileB", "anims_b")):
        phases = []
        for i in range(1, 5):
            key = export_anim(paks, gbk.get(f"{prefix}{i}", ""), anim_cache)
            info = parse_anim_info(viet.get(f"AnimFileInfo{prefix[8:]}{i}", ""))
            phases.append({"anim": key, "frames": info[0], "dirs": info[1], "interval": info[2]} if key else None)
        m[field] = phases
    return m


STATE_TABLE = "\u72b6\u6001\u56fe\u5f62\u5bf9\u7167\u8868.txt"   # bảng đối chiếu trạng thái - hình ảnh


def export_states(paks, state_ids, anim_cache):
    """CStateMagicTable gốc: dòng n của bảng = trạng thái n (StateSpecialId); cột: Status, file, Head/Foot/Body,
    Loop, khung nền bắt đầu/kết thúc, tổng frame, số hướng, nhịp. Ảnh gắn lên người suốt lúc trạng thái còn hiệu lực."""
    lines = Tables().lines(STATE_TABLE)
    out = {}
    for sid in sorted(state_ids):
        if sid <= 0 or sid >= len(lines):
            continue
        cols = lines[sid].split("\t")
        if len(cols) < 9:
            continue
        key = export_anim(paks, cols[1].strip(), anim_cache)
        if not key:
            continue
        out[str(sid)] = {"anim": key, "type": cols[2].strip() or "Body", "loop": cols[3].strip() == "Loop",
                         "back_start": to_int(cols[4]), "back_end": to_int(cols[5]),
                         "frames": max(1, to_int(cols[6], 1)), "dirs": max(1, to_int(cols[7], 1)),
                         "interval": max(1, to_int(cols[8], 1))}
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    monsters_only = "--monsters" in sys.argv and not args and "--all" not in sys.argv
    sects = [] if monsters_only else (ALL_SECTS if "--all" in sys.argv else (args or ["nga_mi"]))
    OUT_DATA.mkdir(parents=True, exist_ok=True)
    OUT_PNG.mkdir(parents=True, exist_ok=True)

    _h, skill_rows = read_table(SKILLS_TXT)
    skill_rows = {to_int(v["SkillId"]): (v, g) for v, g in skill_rows if to_int(v.get("SkillId", ""), -1) > 0}
    _h, missle_rows = read_table(MISSLES_TXT)
    missle_rows = {to_int(v["MissleId"]): (v, g) for v, g in missle_rows if to_int(v.get("MissleId", ""), -1) > 0}

    skills_path, missiles_path, anims_path = OUT_DATA / "skills.json", OUT_DATA / "missiles.json", OUT_DATA / "anims.json"
    load = lambda p: json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}  # noqa: E731
    skills, missiles, anims = load(skills_path), load(missiles_path), load(anims_path)
    paks = _PAKS
    anim_cache = dict(anims)

    roots = sect_root_skills(sects)
    if "--monsters" in sys.argv:
        ## Skill 1-4 của mọi quái (data/monsters/monsters.json do tools/import_vltk_monsters.py xuất).
        mon = json.loads((ROOT / "data/monsters/monsters.json").read_text(encoding="utf-8"))
        roots += sorted({sk for m in mon.values() for sk, _lv in m["skills"] if sk > 0})
    todo, seen, parent_of = list(roots), set(), {}
    while todo:
        sid = todo.pop()
        if sid in seen or sid not in skill_rows:
            continue
        seen.add(sid)
        s = build_skill(*skill_rows[sid])
        s.update(SERVER_OVERRIDES.get(sid, {}))
        precast = export_anim(paks, s.pop("precast"), anim_cache)
        s["precast"] = precast or ""
        if skills.get(str(sid), {}).get("name"):
            s["name"] = skills[str(sid)]["name"]   ## giữ tên đã đặt sẵn (cột tên trong bảng VNG lẫn GBK/TCVN3, dễ hỏng dấu)
        skills[str(sid)] = s
        for ref in referenced_skills(s):
            parent_of.setdefault(ref, sid)
            todo.append(ref)
        if s["base"] == 1 and s["child"] > 0 and s["child"] in missle_rows:
            m = build_missile(*missle_rows[s["child"]], paks, anim_cache)
            if missiles.get(str(s["child"]), {}).get("name"):
                m["name"] = missiles[str(s["child"])]["name"]
            missiles[str(s["child"])] = m
            m["name"] = m["name"] or s["name"]

    ## Skill con/sự kiện tên gốc tiếng Trung -> "<tên skill cha> - phụ" (đạn của nó cũng vậy).
    for sid in sorted(seen, key=lambda i: (i not in roots, i)):
        s = skills[str(sid)]
        if not s["name"]:
            parent = skills.get(str(parent_of.get(sid, 0)), {})
            s["name"] = (parent.get("name") or "Kỹ năng %d" % sid) + " - phụ"
        if s["base"] == 1 and str(s["child"]) in missiles and not missiles[str(s["child"])]["name"]:
            missiles[str(s["child"])]["name"] = s["name"]

    states_path = OUT_DATA / "states.json"
    states = load(states_path)
    states.update(export_states(paks, {int(skills[str(i)].get("state", 0)) for i in seen}, anim_cache))
    anims = {k: v for k, v in anim_cache.items() if v}
    for path, data in ((skills_path, skills), (missiles_path, missiles), (anims_path, anims), (states_path, states)):
        path.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print("phái:", ", ".join(sects), "| skill gốc:", len(roots), "| skill (gồm con/sự kiện):", len(seen),
          "| đạn:", len({str(skills[str(s)]["child"]) for s in seen if skills[str(s)]["base"] == 1}),
          "| ảnh:", len(anims), "| trạng thái:", len(states))


if __name__ == "__main__":
    main()
