"""Tạo file môn phái MỚI của bản 15 phái (Hoa Sơn, Vũ Hồn, Tiêu Dao, Dương Môn, Minh Giáo) -> systems/sect/data/<phái>.tres

    python tools/import_vltk_new_sects.py [phái ...] [--dry]     # không ghi tên phái = cả 5 phái
    python tools/import_vltk_new_sects.py ngu_doc_giao --refresh-lines   # phái cũ theo bản 15 phái: chỉ sinh lại stat_lines

Nguồn (tools/vltk_source.py), không đoán số liệu:
  - Danh sách skill người chơi học được + thứ tự: script/global/nobitaxd/item/faction_def.lua (tbSkillID[phái][cấp]).
  - settings/Skills.txt: tên, mô tả (SkillDesc), ảnh (SkillIcon, frame 0 — KSkill::DrawSkillIcon), cấp yêu cầu, cấp
    tối đa, IsExpSkill (skill luyện), EqtLimit, HorseLimit, LRSkill/Attrib (thi triển được hay nội tại — quy tắc
    KSkillList::GetLeft/RightSkillSortList như tools/mark_castable_skills.py), AttackRadius.
  - settings/gamesetting.ini [SkillAttrib]: dòng "Võ công lưu phái" theo cột Attrib (thiếu thì dùng cột Property).
  - script/skill/<phái>.lua: số liệu theo cấp -> stat_lines (cấp 1 và cấp tối đa) — nhãn lấy theo nhãn các phái cũ
    (combat đọc "Sát thương vật lý", "Băng sát"... từ stat_lines) hoặc magicdesc.ini (data/items/magic_desc.json).
Ghi xong thì chạy tiếp tools/import_vltk_hit_effects.py (vltk_attribs + cờ mục tiêu/đạn) và
tools/import_vltk_skill_fx.py <phái> (hiệu ứng chiêu).
"""
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vltk_source  # noqa: E402
import spr_to_png  # noqa: E402
from import_vltk_hit_effects import lua_attr  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TRES_DIR = ROOT / "systems" / "sect" / "data"
ICON_DIR = ROOT / "assets" / "skill_icons" / "vltk"
ICON_RES = "res://assets/skill_icons/vltk/"
MAGIC_DESC = ROOT / "data" / "items" / "magic_desc.json"

## ElementTypes.ElementType: KIM 0, MOC 1, THUY 2, HOA 3, THO 4 (= Series gốc). SectEnums.Alignment TRUNG_LAP = 2
## (Camp C_BALANCE). Mô tả: lời đệ tử tiếp dẫn trong script/global/monphai/detu*.lua (Vũ Hồn không có lời giới thiệu
## riêng — tóm theo tên skill gốc: thuẫn pháp + đao pháp, Vũ Mục Di Thư, Trung Vu Lưu Phong).
SECTS = {
    "hoa_son": {"index": 10, "name": "Hoa Sơn", "element": 2,
                "description": "Hoa Sơn từ lâu nổi danh với kiếm pháp tinh diệu, môn hạ đệ tử lấy hiệp nghĩa làm đầu; "
                               "chia Kiếm tông và Khí tông."},
    "vu_hon": {"index": 11, "name": "Vũ Hồn", "element": 3,
               "description": "Vũ Hồn Đường kế thừa di chí Vũ Mục, tinh thông thuẫn pháp và đao pháp, tận trung báo quốc, "
                              "diệt gian trừ nịnh."},
    "tieu_dao": {"index": 12, "name": "Tiêu Dao", "element": 4,
                 "description": "Tiêu Dao nhất môn ẩn dật giang hồ, không tranh danh lợi, chỉ cầu tự tại giữa trời đất; "
                                "tinh thông kiếm pháp và cầm pháp."},
    "duong_gia": {"index": 13, "name": "Dương Môn", "element": 0,
                  "description": "Dương gia bao đời trung liệt, một lòng bảo vệ sơn hà Đại Tống; tinh thông thương pháp "
                                 "và cung tiễn trên lưng ngựa."},
    "minh_giao": {"index": 14, "name": "Minh Giáo", "element": 1,
                  "description": "Thánh Hỏa hừng hực chiếu sáng Quang Minh Đỉnh; giáo chúng trên dưới một lòng, hành hiệp "
                                 "trượng nghĩa, tinh thông chùy pháp và kiếm pháp Thánh Hỏa."},
}
TRUNG_LAP = 2

## Thuộc tính lua -> dòng chỉ số giống các phái cũ (SkillDefinition.get_combat_damage_at_level đọc theo nhãn này).
## (nhãn, kiểu): "pct" = 1 số thành phần [0] hậu tố "%"; "num" = 1 số [0]; "range" = [0] đến [2] điểm;
## "link" = addskilldamageN: [0] = SkillId đích, [2] = %.
FIXED_LABELS = {
    "physicsenhance_p": ("Sát thương vật lý", "pct"),
    "physicsdamage_v": ("Sát thương vật lý", "range"),
    "colddamage_v": ("Băng sát", "range"),
    "firedamage_v": ("Hỏa sát", "range"),
    "lightingdamage_v": ("Lôi sát", "range"),
    "poisondamage_v": ("Độc sát", "poison"),
    "seriesdamage_p": ("Ngũ hành tương khắc", "pct"),
    "deadlystrike_p": ("Tấn công chí mạng", "pct"),
    "skill_cost_v": ("Tiêu hao nội lực", "num"),
}
## Không hiện thành dòng chỉ số (tham số kỹ thuật của đạn/sự kiện/luyện skill).
SKIP_ATTRIBS = re.compile(r"^(skill_(?!cost_v)|missle_|addskillexp|autoattackskill|autorescueskill|autodeathskill|"
                          r"autoreplyskill|addstartskill|addflyskill|addvanishskill|addcollideskill)")
## Thời gian (cấp game 18 nhịp/giây) — giá trị frame quy ra giây khi magicdesc ghi #f.
GAME_FPS = 18.0


def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")


def slug(text: str) -> str:
    text = unicodedata.normalize("NFD", text.replace("đ", "d").replace("Đ", "D"))
    text = "".join(c for c in text if unicodedata.category(c) != "Mn").lower()
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def title(name: str) -> str:
    """Viết hoa chữ đầu mỗi từ (Skills.txt có tên viết thường lẫn lộn: "Cửu kiếm hợp nhất", "ỷ Kiếm Phất Thiên")."""
    return " ".join(w[:1].upper() + w[1:] for w in name.split())


def sentence(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip().strip('"').strip()
    return text[:1].upper() + text[1:]


def load_skill_rows() -> dict:
    """SkillId -> {cột: chữ UTF-8} + "_icon" (đường dẫn ảnh GBK gốc)."""
    path = vltk_source.settings_file("skills.txt")
    raw = path.read_bytes().split(b"\n")
    lines = iconv(path).split("\n")
    header = lines[0].rstrip("\r").split("\t")
    icon_col = header.index("SkillIcon")
    rows = {}
    for raw_line, line in zip(raw[1:], lines[1:]):
        cells = line.rstrip("\r").split("\t")
        if len(cells) < 4 or not cells[2].strip().isdigit():
            continue
        row = {h: (cells[i].strip() if i < len(cells) else "") for i, h in enumerate(header)}
        raw_cells = raw_line.rstrip(b"\r").split(b"\t")
        row["_icon"] = raw_cells[icon_col].strip().decode("gbk", "replace") if len(raw_cells) > icon_col else ""
        rows.setdefault(int(cells[2]), row)
    return rows


def load_school_texts() -> dict:
    text = iconv(vltk_source.settings_file("gamesetting.ini"))
    body = text.split("[SkillAttrib]", 1)[1].split("\n[", 1)[0]
    out = {}
    for m in re.finditer(r"^(\d+)=(.*)$", body, re.M):
        value = re.sub(r"<color(=[^>]*)?>", "", m.group(2)).strip()
        out[int(m.group(1))] = value.replace("Võ công lưu phái:", "").strip()
    return out


def load_faction_skills() -> dict:
    """faction_def.lua: {chỉ số phái: [SkillId theo thứ tự cấp mở]}."""
    text = (vltk_source.SCRIPT / "global/nobitaxd/item/faction_def.lua").read_bytes().decode("latin-1")
    out = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*\{\s*szFacName=.*?tbSkillID=\{([^\n]*)", text, re.S):
        ids = []
        for level_m in re.finditer(r"\[(\d+)\]=\{((?:\{[^{}]*\},?)*)\}", m.group(2)):
            ids += [int(x) for x in re.findall(r"\{(\d+),", level_m.group(2))]
        out[int(m.group(1))] = ids
    return out


def num(text: str, default: int = 0) -> int:
    try:
        return int(float(text))
    except ValueError:
        return default


def eval_points(comp, level: int):
    """Giá trị 1 thành phần lua tại `level` — nội suy tuyến tính giữa các mốc (như SkillDefinition.eval_level_points
    với hàm Line; Conic/Extrac hiếm, dùng tuyến tính cho dòng hiển thị)."""
    if not isinstance(comp, list):
        return None
    pts = [(p[0], p[1]) for p in comp if isinstance(p, list) and len(p) >= 2
           and isinstance(p[0], float) and isinstance(p[1], float)]
    if not pts:
        return None
    pts.sort()
    if level <= pts[0][0]:
        return pts[0][1]
    for (l0, v0), (l1, v1) in zip(pts, pts[1:]):
        if level <= l1:
            return v0 + (v1 - v0) * (level - l0) / (l1 - l0) if l1 != l0 else v1
    return pts[-1][1]


def desc_label(magic_desc: dict, attr: str):
    """magicdesc "Tốc độ di chuyển: #d1+%" -> ("Tốc độ di chuyển", "%", "num"|"range"|"time")."""
    fmt = magic_desc.get(attr)
    if not fmt:
        return None
    fmt = re.sub(r"<color(=[^>]*)?>", "", fmt)
    head, _, tail = fmt.partition(":")
    if not tail or "#" not in tail:
        return None
    if "#d3" in tail:
        kind = "range"
    elif "#f1" in tail:
        kind = "time"
    else:
        kind = "num"
    suffix = re.sub(r"#[a-z]\d[+-]?", "", tail.split("đến")[-1]).strip()
    suffix = "%" if suffix.startswith("%") else (" " + suffix if suffix else "")
    return head.strip(), suffix, kind


def stat_lines_for(row: dict, max_level: int, magic_desc: dict, id_by_vltk: dict, names: dict) -> list:
    script = row.get("LvlSetScript", "").replace("\\", "/").lstrip("/")
    seen, attrs = set(), []
    n = 1
    while "LvlSetting%d" % n in row:
        attr, table = row["LvlSetting%d" % n], row["LvlData%d" % n]
        if attr and table and attr not in seen:
            seen.add(attr)
            attrs.append((attr, table))
        n += 1
    lines = []
    link_index = 0
    for attr, table in attrs:
        if SKIP_ATTRIBS.match(attr) and attr != "skill_cost_v":
            continue
        comps = lua_attr(script, table, attr)
        if not isinstance(comps, list) or not comps:
            continue
        comps = (comps + [None, None, None])[:3]
        at = lambda c, lv: eval_points(comps[c], lv)  # noqa: E731
        if attr.startswith("addskilldamage"):
            target, lo, hi = at(0, 1), at(2, 1), at(2, max_level)
            if target is None or lo is None:
                continue
            link_index += 1
            line = {"label": "Tăng sát thương kỹ năng liên kết #%d" % link_index, "value_at_level_1": lo,
                    "value_at_max_level": hi, "suffix": "%"}
            target_id = id_by_vltk.get(int(target))
            if target_id:
                line["target_skill_id"] = target_id
            elif re.search(r"[A-Za-z]", names.get(int(target), "")):   ## tên gốc tiếng Trung (không chữ Latin) -> bỏ
                line["label"] += " (%s)" % names[int(target)]
            lines.append(line)
            continue
        if attr in FIXED_LABELS:
            label, kind = FIXED_LABELS[attr]
            suffix = {"pct": "%", "range": " điểm", "poison": " điểm/lần", "num": ""}[kind]
            kind = "num" if kind in ("pct", "poison") else kind
        else:
            info = desc_label(magic_desc, attr)
            if info is None:
                continue
            label, suffix, kind = info
        if kind == "range":
            vals = [at(0, 1), at(2, 1), at(0, max_level), at(2, max_level)]
            if vals[0] is None:
                continue
            vals = [v if v is not None else vals[i - 1] for i, v in enumerate(vals)]
            lines.append({"label": label, "is_range": True, "min_at_level_1": vals[0], "max_at_level_1": vals[1],
                          "min_at_max_level": vals[2], "max_at_max_level": vals[3], "suffix": " điểm"})
            continue
        lo, hi = at(0, 1), at(0, max_level)
        if lo is None:
            continue
        if kind == "time":
            lo, hi, suffix = lo / GAME_FPS, hi / GAME_FPS, " giây"
        lines.append({"label": label, "value_at_level_1": lo, "value_at_max_level": hi, "suffix": suffix})
    return lines


def fmt_float(v: float) -> str:
    return repr(round(float(v), 4))


def statline_block(sub_id: str, line: dict) -> str:
    body = ['[sub_resource type="Resource" id="%s"]' % sub_id, 'script = ExtResource("3_statline")',
            'label = "%s"' % line["label"]]
    if line.get("is_range"):
        body.append("is_range = true")
        for k in ("min_at_level_1", "max_at_level_1", "min_at_max_level", "max_at_max_level"):
            body.append("%s = %s" % (k, fmt_float(line[k])))
    else:
        body.append("value_at_level_1 = %s" % fmt_float(line["value_at_level_1"]))
        body.append("value_at_max_level = %s" % fmt_float(line["value_at_max_level"]))
    if line["suffix"]:
        body.append('suffix = "%s"' % line["suffix"])
    if line.get("target_skill_id"):
        body.append('target_skill_id = "%s"' % line["target_skill_id"])
    return "\n".join(body)


def refresh_lines(sect: str, rows: dict, magic_desc: dict, dry: bool) -> None:
    """Phái CŨ lấy số liệu theo bản 15 phái (vltk_source.JX15_DATA_SECTS — Ngũ Độc): sinh lại stat_lines của mọi skill có
    vltk_skill_id từ lua mới (combat đọc sát thương từ stat_lines); skill không có SkillId (skill con ẩn) giữ nguyên."""
    path = TRES_DIR / (sect + ".tres")
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"(?=\n\[sub_resource|\n\[resource\])", text)
    id_by_vltk = {}
    for b in blocks:
        i, sid = re.search(r"^vltk_skill_id = (\d+)", b, re.M), re.search(r'^id = "([^"]*)"', b, re.M)
        if i and sid and 'script = ExtResource("2_skill")' in b:
            id_by_vltk.setdefault(int(i.group(1)), sid.group(1))
    names = {i: title(r["SkillName"]) for i, r in rows.items()}
    out, changed = [], 0
    n_new = max([int(x) for x in re.findall(r'id="SubResource_jx15_(\d+)"', text)] + [0])  ## chạy lại không trùng id
    for b in blocks:
        i = re.search(r"^vltk_skill_id = (\d+)", b, re.M)
        lines_m = re.search(r"^stat_lines = .*$", b, re.M)
        if not (i and lines_m and int(i.group(1)) in rows and 'script = ExtResource("2_skill")' in b):
            out.append(b)
            continue
        row = rows[int(i.group(1))]
        max_m = re.search(r"^max_level = (\d+)", b, re.M)
        max_level = int(max_m.group(1)) if max_m else 10
        refs = []
        for line in stat_lines_for(row, max_level, magic_desc, id_by_vltk, names):
            n_new += 1
            sub_id = "SubResource_jx15_%d" % n_new
            out.append("\n\n" + statline_block(sub_id, line))
            refs.append('SubResource("%s")' % sub_id)
        out.append(b[:lines_m.start()] + 'stat_lines = Array[ExtResource("3_statline")]([%s])' % ", ".join(refs)
                   + b[lines_m.end():])
        changed += 1
    text = "".join(out)
    ## Bỏ dòng chỉ số cũ không còn skill nào dùng.
    parts = re.split(r"(?=\n\[sub_resource|\n\[resource\])", text)
    keep = []
    for part in parts:
        m = re.match(r'\n\[sub_resource type="Resource" id="([^"]+)"\]\nscript = ExtResource\("3_statline"\)', part)
        if m and text.count('SubResource("%s")' % m.group(1)) == 0:
            continue
        keep.append(part)
    text = "".join(keep)
    print("%s: sinh lại dòng chỉ số %d skill (%d dòng)" % (sect, changed, n_new))
    if not dry:
        path.write_text(text, encoding="utf-8", newline="\n")


def save_icon(row: dict, skill_id: str, dry: bool) -> bool:
    png = ICON_DIR / (skill_id + ".png")
    if png.is_file():
        return True
    data = vltk_source.client_file(row["_icon"]) if row["_icon"] else None
    if data is None:
        return False
    tmp = Path(vltk_source.SERVER) / "_icon_tmp.spr"
    tmp.write_bytes(data)
    try:
        images, _meta = spr_to_png.read_spr(str(tmp))
    finally:
        tmp.unlink()
    if not dry:
        ICON_DIR.mkdir(parents=True, exist_ok=True)
        images[0].save(png, optimize=True)
    return True


def build_sect(sect: str, rows: dict, faction_skills: dict, schools: dict, magic_desc: dict, dry: bool) -> str:
    meta = SECTS[sect]
    ids = [i for i in faction_skills[meta["index"]] if i in rows]
    names = {i: title(r["SkillName"]) for i, r in rows.items()}
    id_by_vltk = {}
    for i in ids:
        id_by_vltk[i] = "%s_%s" % (sect, slug(names[i]))
    ext = ['[ext_resource type="Script" path="res://systems/sect/sect_definition.gd" id="1_sect"]',
           '[ext_resource type="Script" path="res://systems/sect/skill_definition.gd" id="2_skill"]',
           '[ext_resource type="Script" path="res://systems/sect/skill_stat_line.gd" id="3_statline"]']
    subs, skill_refs = [], []
    sub_n = 0
    main_attack_done = False
    for i in ids:
        row = rows[i]
        sid = id_by_vltk[i]
        max_level = max(1, num(row["MaxLevel"], 20))
        lr, attrib = num(row["LRSkill"]), num(row["Attrib"])
        active = (attrib > 1 and lr == 0) or lr in (1, 2)
        target_enemy = row["TargetEnemy"] == "1"
        line_refs = []
        for line in stat_lines_for(row, max_level, magic_desc, id_by_vltk, names):
            sub_n += 1
            subs.append(statline_block("SubResource_%d" % sub_n, line))
            line_refs.append('SubResource("SubResource_%d")' % sub_n)
        ## Số MÔ PHỎNG cho combat cũ (base_damage/growth) = sát thương hệ/vật lý thấp nhất cấp 1 -> cấp tối đa.
        dmg = next((ln for ln in stat_lines_for(row, max_level, magic_desc, id_by_vltk, names)
                    if ln.get("is_range")), None)
        base = dmg["min_at_level_1"] if dmg else 0.0
        growth = (dmg["min_at_max_level"] - base) / (max_level - 1) if dmg and max_level > 1 else 0.0
        has_icon = save_icon(row, sid, dry)
        if has_icon:
            ext.append('[ext_resource type="Texture2D" path="%s%s.png" id="vicon_%s"]' % (ICON_RES, sid, sid))
        school = schools.get(attrib) or sentence(row.get("Property", ""))
        sub_n += 1
        body = ['[sub_resource type="Resource" id="SubResource_%d"]' % sub_n, 'script = ExtResource("2_skill")',
                'id = "%s"' % sid, 'skill_name = "%s"' % names[i]]
        req = max(1, num(row["ReqLevel"], 1))
        body.append("req_level = %d" % req)
        if row["IsExpSkill"] == "1":
            body.append("practice_only = true")
        body.append("vltk_skill_id = %d" % i)
        if row["EqtLimit"] != "" and num(row["EqtLimit"], -2) != -2:
            body.append("weapon_limit = %d" % num(row["EqtLimit"], -2))
        if num(row["HorseLimit"]):
            body.append("horse_limit = %d" % num(row["HorseLimit"]))
        if has_icon:
            body.append('icon = ExtResource("vicon_%s")' % sid)
        body += ['description = "%s"' % sentence(row.get("SkillDesc", "")).replace('"', "'"),
                 'school_text = "%s"' % school,
                 "is_active = %s" % ("true" if active else "false"),
                 "category = %d" % (0 if active else 1),
                 "max_level = %d" % max_level,
                 "base_damage = %s" % fmt_float(base),
                 "mana_cost = 0.0",
                 "cooldown = %s" % (("1.6" if req <= 20 else "2.2") if active and target_enemy else
                                    ("8.0" if active else "0.0")),
                 "range = %s" % fmt_float(num(row["AttackRadius"]) * 1.6 if active and target_enemy else 0.0),
                 "element = %d" % meta["element"],
                 "damage_growth_per_level = %s" % fmt_float(growth),
                 'stat_lines = Array[ExtResource("3_statline")]([%s])' % ", ".join(line_refs)]
        if active and target_enemy and not main_attack_done:
            body.append("is_main_attack = true")
            main_attack_done = True
        subs.append("\n".join(body))
        skill_refs.append('SubResource("SubResource_%d")' % sub_n)
    resource = ["[resource]", 'script = ExtResource("1_sect")', 'id = "%s"' % sect, 'sect_name = "%s"' % meta["name"],
                "element = %d" % meta["element"], "alignment = %d" % TRUNG_LAP,
                'description = "%s"' % meta["description"],
                'skills = Array[ExtResource("2_skill")]([%s])' % ", ".join(skill_refs)]
    head = '[gd_resource type="Resource" script_class="SectDefinition" format=3]'
    print("%-10s %d skill: %s" % (sect, len(ids), " | ".join(names[i] for i in ids)))
    return "\n\n".join([head, "\n".join(ext)] + subs + ["\n".join(resource)]) + "\n"


def main():
    dry = "--dry" in sys.argv
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")] or list(SECTS)
    rows = load_skill_rows()
    faction_skills = load_faction_skills()
    schools = load_school_texts()
    magic_desc = json.loads(MAGIC_DESC.read_text(encoding="utf-8"))
    if "--refresh-lines" in sys.argv:
        for sect in wanted:
            refresh_lines(sect, rows, magic_desc, dry)
        return
    for sect in wanted:
        text = build_sect(sect, rows, faction_skills, schools, magic_desc, dry)
        if not dry:
            (TRES_DIR / (sect + ".tres")).write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
