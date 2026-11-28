"""Đối chiếu những gì popup skill hiển thị với nguồn gốc VLTK — không sửa file nào, chỉ báo cáo.

    python tools/audit_skill_display.py [phái ...]          # in ra màn hình + ghi docs/qa_reports/skill_display_audit.md
    python tools/audit_skill_display.py --fill              # + ghi level_points (mốc lua) cho dòng chỉ số lệch đường cong

Nguồn: 9 phái cũ = Skills.txt / gamesetting.ini trong pak client VNG + lua skill anh-việt (như import_vltk_hit_effects.py);
5 phái mới + Ngũ Độc = server 15 phái (tools/vltk_source.py). So: tên, "lưu phái" (gamesetting.ini [SkillAttrib] theo cột
Attrib), nội/ngoại công (IsPhysical), cấp tối đa, hạn chế vũ khí (EqtLimit), ngựa (HorseLimit), và số của từng dòng chỉ số
ở MỌI cấp với TOÀN BỘ bảng lua (Link nhiều mốc). Dòng sát thương đọc vltk_attribs (cùng nguồn) thì không so lại số."""
import json
import math
import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
import import_vltk_hit_effects as H  # noqa: E402  (nạp Skills.txt VNG từ pak)
import import_vltk_new_sects as N  # noqa: E402
import vltk_source  # noqa: E402
import vltk_pak  # noqa: E402

TRES = REPO / "systems" / "sect" / "data"
magic_desc = json.loads((REPO / "data/items/magic_desc.json").read_text(encoding="utf-8"))


def tcvn(data: bytes) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=data, capture_output=True).stdout.decode("utf-8", "replace")


def load_rows(path: Path) -> dict:
    lines = tcvn(path.read_bytes()).split("\n")
    header = lines[0].rstrip("\r").split("\t")
    rows = {}
    for line in lines[1:]:
        cells = line.rstrip("\r").split("\t")
        if len(cells) < 4 or not cells[2].strip().isdigit():
            continue
        rows.setdefault(int(cells[2]), {h: (cells[i].strip() if i < len(cells) else "") for i, h in enumerate(header)})
    return rows


def schools_from(text: str) -> dict:
    body = text.split("[SkillAttrib]", 1)[1].split("\n[", 1)[0]
    out = {}
    for m in re.finditer(r"^(\d+)=(.*)$", body, re.M):
        v = re.sub(r"<color(=[^>]*)?>", "", m.group(2)).strip()
        out[int(m.group(1))] = v.replace("Võ công lưu phái:", "").strip()
    return out


def vng_gamesetting() -> str:
    paks = vltk_pak.PakList.__new__(vltk_pak.PakList)
    paks.client_dir, paks.paks = H.VNG_CLIENT, []
    for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
        f = os.path.join(H.VNG_CLIENT, "data", n + ".pak")
        if os.path.isfile(f):
            paks.paks.append(vltk_pak.PakFile(f))
    data = paks.read("settings/gamesetting.ini")
    return tcvn(data) if data else ""


SRC = {
    "old": {"rows": load_rows(H.SKILLS_TXT), "lua": H.LUA_DIRS},
    "new": {"rows": load_rows(vltk_source.settings_file("skills.txt")), "lua": H.NEW_LUA_DIRS},
}
g_old = vng_gamesetting()
FACTION = N.load_faction_skills()
LEARN_LEVEL = {}
_fd = (vltk_source.SCRIPT / "global/nobitaxd/item/faction_def.lua").read_bytes().decode("latin-1")
for _m in re.finditer(r"\[(\d+)\]\s*=\s*\{\s*szFacName=.*?tbSkillID=\{([^\n]*)", _fd, re.S):
    for _lm in re.finditer(r"\[(\d+)\]=\{((?:\{[^{}]*\},?)*)\}", _m.group(2)):
        for _x in re.findall(r"\{(\d+),", _lm.group(2)):
            LEARN_LEVEL.setdefault((int(_m.group(1)), int(_x)), int(_lm.group(1)))
SRC["new"]["school"] = schools_from(tcvn(vltk_source.settings_file("gamesetting.ini").read_bytes()))
SRC["old"]["school"] = schools_from(g_old) if "[SkillAttrib]" in g_old else SRC["new"]["school"]
print("gamesetting VNG:", "có" if "[SkillAttrib]" in g_old else "KHÔNG có -> dùng bản 15 phái")


def lua_val(comp, level):
    """Link gốc: Line piecewise, ngoại suy theo đoạn cuối (giống eval_level_points; Conic hiếm -> bỏ qua)."""
    pts = sorted((p[0], p[1]) for p in comp if isinstance(p, list) and len(p) >= 2 and isinstance(p[0], float) and isinstance(p[1], float))
    if not pts:
        return None
    if len(pts) == 1:
        return pts[0][1]
    seg = 1
    if level > pts[-1][0]:
        seg = len(pts) - 1
    elif level >= pts[0][0]:
        for i in range(1, len(pts)):
            if level <= pts[i][0]:
                seg = i
                break
    (x1, y1), (x2, y2) = pts[seg - 1], pts[seg]
    if x1 == x2:
        return y2
    return y1 + (y2 - y1) * (level - x1) / (x2 - x1)


def _pts(literal):
    """'PackedFloat32Array(1, 40, 0, 15, 60, 0)' -> [[1.0, 40.0], ...] cho lua_val."""
    nums = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", literal.split("(", 1)[1])] if literal and "(" in literal else []
    return [[nums[i], nums[i + 1]] for i in range(0, len(nums) - 2, 3)]


def expected_lines(row, max_level, lua_dirs):
    """[(nhãn, kiểu, hàm(cấp)->(min,max), hậu tố)] theo lua gốc — cùng quy tắc nhãn với importer."""
    script = row.get("LvlSetScript", "").replace("\\", "/").lstrip("/")
    seen, attrs, n = set(), [], 1
    tables = []
    while "LvlSetting%d" % n in row:
        a, t = row["LvlSetting%d" % n], row["LvlData%d" % n]
        if t and t not in tables:
            tables.append(t)
        n += 1
    ## Toàn bộ khoá trong bảng lua (engine đọc cả bảng; cột LvlSetting của Skills.txt chỉ liệt kê một phần)
    for t in tables:
        H.lua_attr(script, t, "__none__", lua_dirs)
        text = H._lua_cache.get((script, tuple(lua_dirs)))
        if not text:
            continue
        m = re.search(r"(?<![\w])" + re.escape(t) + r"\s*=\s*\{", text)
        if not m:
            continue
        block = text[m.end() - 1: H.match_brace(text, m.end() - 1) + 1]
        depth = 0
        i = 0
        while i < len(block):
            ch = block[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            elif depth == 1:
                km = re.match(r"([A-Za-z_][A-Za-z_0-9]*)\s*=\s*\{", block[i:])
                if km and (i == 0 or not (block[i - 1].isalnum() or block[i - 1] == "_")):
                    a = km.group(1)
                    if a not in seen:
                        seen.add(a)
                        attrs.append((a, t))
                    i += km.end() - 1
                    continue
            i += 1
    out, link = [], 0
    for attr, table in attrs:
        if N.SKIP_ATTRIBS.match(attr) and attr != "skill_cost_v":
            continue
        comps = H.lua_attr(script, table, attr, lua_dirs)
        if not isinstance(comps, list) or not comps:
            continue
        comps = (comps + [None, None, None])[:3]
        if attr.startswith("addskilldamage"):
            if comps[2] is None or not isinstance(comps[0], list):
                continue
            link += 1
            target = lua_val(comps[0], 1)
            out.append(("Tăng sát thương kỹ năng liên kết #%d" % link, "num",
                        (lambda c: lambda lv: (lua_val(c, lv), lua_val(c, lv)))(comps[2]), "%", attr, int(target or 0),
                        (comps[2], None, 1.0)))
            continue
        if attr in N.FIXED_LABELS:
            label, kind = N.FIXED_LABELS[attr]
            kind = "num" if kind in ("pct", "poison") else kind
        else:
            info = N.desc_label(magic_desc, attr)
            if info is None:
                continue
            label, _suf, kind = info
        if kind == "range":
            c0 = comps[0]; c2 = comps[2] if isinstance(comps[2], list) else comps[0]
            if not isinstance(c0, list):
                continue
            out.append((label, "range", (lambda a, b: lambda lv: (lua_val(a, lv), lua_val(b, lv)))(c0, c2), " điểm", attr, 0, (c0, c2, 1.0)))
        else:
            if not isinstance(comps[0], list):
                continue
            div = N.GAME_FPS if kind == "time" else 1.0
            out.append((label, kind, (lambda c, d: lambda lv: (lua_val(c, lv) / d, lua_val(c, lv) / d))(comps[0], div), "", attr, 0, (comps[0], None, div)))
    return out


def parse_tres(path: Path):
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"(?=\n\[sub_resource|\n\[resource\])", text)
    subs, skills = {}, []
    for b in blocks:
        m = re.match(r'\n\[sub_resource type="Resource" id="([^"]+)"\]', b)
        f = lambda k, d=None: (lambda mm: mm.group(1) if mm else d)(re.search(r"^%s = (.*)$" % k, b, re.M))  # noqa: E731
        if m and "label = " in b:
            subs[m.group(1)] = {k: f(k) for k in ("level_points", "level_points_max", "label", "is_range", "value_at_level_1", "value_at_max_level", "min_at_level_1",
                                                  "max_at_level_1", "min_at_max_level", "max_at_max_level", "suffix", "target_skill_id")}
        elif f("skill_name"):
            refs = re.findall(r'SubResource\("([^"]+)"\)', f("stat_lines", "") or "")
            skills.append({k: f(k) for k in ("id", "skill_name", "school_text", "req_level", "max_level", "weapon_limit",
                                            "horse_limit", "vltk_skill_id", "vltk_is_physical", "is_hidden", "parent_skill_id",
                                            "category")} | {"lines": refs, "has_attribs": "vltk_attribs = {" in b,
                                                            "attribs_text": b})
    return subs, skills


def unq(s):
    return (s or "").strip('"')


def fnum(s, d=0.0):
    try:
        return float(s)
    except (TypeError, ValueError):
        return d


def game_value(line, skill_max, lv):
    """Giống SkillDefinition.stat_line_range khi KHÔNG có thuộc tính gốc: có level_points thì theo mốc, không thì nội suy
    tuyến tính L1 -> max (floor)."""
    if line.get("level_points"):
        lo = lua_val(_pts(line["level_points"]), lv)
        hi = lua_val(_pts(line["level_points_max"]), lv) if line.get("level_points_max") else lo
        return math.floor(lo + 1e-6), math.floor(hi + 1e-6)
    def interp(a, b):
        if skill_max <= 1:
            return math.floor(a)
        t = min(max((lv - 1) / (skill_max - 1), 0.0), 1.0)
        return math.floor(a + (b - a) * t)
    if line["is_range"] == "true":
        return interp(fnum(line["min_at_level_1"]), fnum(line["min_at_max_level"])), interp(fnum(line["max_at_level_1"]), fnum(line["max_at_max_level"]))
    v = interp(fnum(line["value_at_level_1"]), fnum(line["value_at_max_level"]))
    return v, v


DAMAGE_LABEL_ATTR = {"Lôi sát": "lightingdamage_v", "Băng sát": "colddamage_v", "Hỏa sát": "firedamage_v", "Độc sát": "poisondamage_v",
                     "Ngũ hành tương khắc": "seriesdamage_p", "Tấn công chí mạng": "deadlystrike_p"}
WEAPON_TEXT_HINT = {-2: "", -1: "Tự tiến"}


def base_name(n):
    n = re.sub(r"\s*\((hệ [^)]*|Tăng \d+|Va Chạm)\)\s*$", "", n)
    return n.strip()


def norm(s):
    return re.sub(r"\s+", " ", s or "").strip().lower()


only = [a for a in sys.argv[1:] if not a.startswith("-")]
FILL = "--fill" in sys.argv
FILLS = {}


def _scaled_literal(comp, div):
    if div == 1.0 or not comp:
        return H.points_literal(comp)
    return H.points_literal([[p[0], p[1] / div] + list(p[2:]) if isinstance(p, list) and len(p) >= 2 and isinstance(p[1], float) else p
                             for p in comp])
report = {}
for tres in sorted(TRES.glob("*.tres")):
    sect = tres.stem
    if only and sect not in only:
        continue
    src = SRC["new" if sect in vltk_source.JX15_DATA_SECTS else "old"]
    subs, skills = parse_tres(tres)
    id_by_vltk = {int(unq(s["vltk_skill_id"])): unq(s["id"]) for s in skills if s["vltk_skill_id"]}
    issues = []
    for s in skills:
        name = unq(s["skill_name"])
        hidden = s["is_hidden"] == "true"
        vid = int(s["vltk_skill_id"] or 0)
        tag = name + (" [ẩn]" if hidden else "")
        if not vid:
            issues.append((tag, "không có vltk_skill_id — không đối chiếu được", "", ""))
            continue
        row = src["rows"].get(vid)
        if not row:
            issues.append((tag, "SkillId %d không có trong Skills.txt" % vid, "", ""))
            continue
        src_name = N.title(row["SkillName"]) if row["SkillName"] else ""
        if norm(base_name(name)) != norm(src_name) and norm(name) != norm(src_name):
            issues.append((tag, "Tên", name, src_name))
        # Lưu phái
        attrib = N.num(row.get("Attrib", ""), -1)
        prop = N.num(row.get("Property", ""), -1)
        exp_school = src["school"].get(attrib) or src["school"].get(prop) or ""
        game_school = unq(s["school_text"])
        if exp_school and norm(game_school) != norm(exp_school):
            issues.append((tag, "Lưu phái", game_school, exp_school))
        phys = row.get("IsPhysical", "")
        if game_school and phys in ("0", "1"):
            if phys == "0" and "ngoại công" in game_school.lower():
                issues.append((tag, "Nội/ngoại công", game_school, "IsPhysical=0 (nội công)"))
            if phys == "1" and "nội công)" in game_school.lower():
                issues.append((tag, "Nội/ngoại công", game_school, "IsPhysical=1 (ngoại công)"))
        sidx = vltk_source.SECTS.index(sect)
        ll = LEARN_LEVEL.get((sidx, vid))
        greq = int(s["req_level"] or 1)
        for field, col, default in (("max_level", "MaxLevel", 10), ("weapon_limit", "EqtLimit", -2), ("horse_limit", "HorseLimit", 0)):
            g = int(s[field]) if s[field] not in (None, "") else default
            e = N.num(row.get(col, ""), default)
            if field == "req_level" and e <= 1 and g <= 1:
                continue
            if g != e:
                issues.append((tag, field, str(g), "%s=%d" % (col, e)))
        # Dòng chỉ số
        smax = int(s["max_level"] or 10)
        exp = expected_lines(row, smax, src["lua"])
        glines = [dict(subs[r], _sub=r) for r in s["lines"] if r in subs]
        used = set()
        for gl in glines:
            label = unq(gl["label"])
            cands = [i for i, e in enumerate(exp) if i not in used and norm(e[0]) == norm(label)]
            if not cands:
                cands = [i for i, e in enumerate(exp) if i not in used and norm(label).startswith(norm(e[0]))]
            relabel = None
            if not cands:
                for i, e in enumerate(exp):
                    if i in used or e[2](1)[0] is None:
                        continue
                    g1, gm = game_value(gl, smax, 1), game_value(gl, smax, smax)
                    e1, em = e[2](1), e[2](smax)
                    if abs(g1[0] - math.floor(e1[0] + 1e-6)) <= 1 and abs(gm[0] - math.floor(em[0] + 1e-6)) <= 1 and (g1[0] or gm[0]):
                        cands = [i]; relabel = e[0]; break
            if not cands:
                issues.append((tag, "Dòng không có trong gốc", label, ""))
                continue
            if relabel:
                issues.append((tag, "Nhãn khác (số khớp)", label, relabel))
            i = cands[0]; used.add(i)
            e = exp[i]
            # dòng damage có vltk_attribs: game dùng thuộc tính gốc (cùng nguồn) -> bỏ qua so số
            uses_attrib = e[4] in ("physicsdamage_v", "colddamage_v", "firedamage_v", "lightingdamage_v", "poisondamage_v",
                                   "seriesdamage_p", "deadlystrike_p", "physicsenhance_p") and ("\"%s\"" % e[4]) in s["attribs_text"]
            if uses_attrib:
                continue
            bad = []
            for lv in range(1, smax + 1):
                gv = game_value(gl, smax, lv)
                ev = e[2](lv)
                if ev[0] is None:
                    break
                ev = (math.floor(ev[0] + 1e-6), math.floor(ev[1] + 1e-6))
                if abs(gv[0] - ev[0]) > 1 or abs(gv[1] - ev[1]) > 1:
                    bad.append((lv, gv, ev))
            if bad and FILL:
                g1, gm = game_value(gl, smax, 1), game_value(gl, smax, smax)
                e1, em = e[2](1), e[2](smax)
                ## Cùng thuộc tính khi cấp 1 khớp và "giá trị cấp tối đa" của game = gốc tại max_level HOẶC = mốc cuối của
                ## lua (importer cũ lấy mốc cuối — VD cấp 26 dành cho cấp cộng thêm — làm giá trị cấp tối đa).
                last = max((p[0] for p in (e[6][0] or []) if isinstance(p, list) and p and isinstance(p[0], float)), default=smax)
                el = e[2](int(last))
                close = lambda a, b: abs(a - math.floor(b + 1e-6)) <= 1  # noqa: E731
                ends_ok = close(g1[0], e1[0]) and close(g1[1], e1[1]) and (
                    (close(gm[0], em[0]) and close(gm[1], em[1])) or (close(gm[0], el[0]) and close(gm[1], el[1])))
                ## Nhãn trùng đúng thuộc tính gốc (không phải ghép theo số) cũng ghi — trừ dòng liên kết #N (thứ tự có thể đảo).
                if not ends_ok and not relabel and not e[4].startswith("addskilldamage"):
                    ends_ok = True
                if ends_ok:
                    FILLS.setdefault(sect, []).append((gl["_sub"], e[6]))
                    continue
            if bad:
                lv, gv, ev = bad[0]
                fmt = lambda v: str(v[0]) if v[0] == v[1] else "%d-%d" % v  # noqa: E731
                issues.append((tag, "Số liệu '%s'" % label, "cấp %d: %s (lệch %d/%d cấp)" % (lv, fmt(gv), len(bad), smax), "gốc: %s" % fmt(ev)))
            if e[5]:
                tgt = id_by_vltk.get(e[5])
                gt = unq(gl["target_skill_id"])
                if tgt and gt and gt != tgt:
                    issues.append((tag, "Đích '%s'" % label, gt, tgt))
        for i, e in enumerate(exp):
            if i not in used:
                issues.append((tag, "Thiếu dòng gốc", "", e[0]))
    report[sect] = issues

for sect, issues in report.items():
    print("\n=== %s: %d mục" % (sect, len(issues)))
    for t, kind, g, e in issues:
        print("  - %s | %s | game: %s | gốc: %s" % (t, kind, g, e))

if FILL:
    for sect, fills in FILLS.items():
        p = TRES / (sect + ".tres")
        text = p.read_text(encoding="utf-8")
        for sub, (lo, hi, div) in fills:
            head = '[sub_resource type="Resource" id="%s"]' % sub
            start = text.index(head)
            end = text.find("\n[", start + 1)
            block = text[start:end]
            block = re.sub(r"\nlevel_points(_max)? = .*", "", block)
            add = "\nlevel_points = " + _scaled_literal(lo, div)
            if hi is not None:
                add += "\nlevel_points_max = " + _scaled_literal(hi, div)
            block = block.replace('script = ExtResource("3_statline")', 'script = ExtResource("3_statline")' + add, 1)
            text = text[:start] + block + text[end:]
        p.write_text(text, encoding="utf-8", newline="\n")
        print("%s: ghi mốc lua cho %d dòng" % (sect, len(fills)))

## ---- báo cáo markdown ----
GROUPS = [
    ("Nội/ngoại công", "Ghi sai nội/ngoại công (so IsPhysical)", "Chữ trong ngoặc của dòng lưu phái ngược với IsPhysical gốc. Combat KHÔNG sai (đọc vltk_is_physical), chỉ chữ hiển thị sai."),
    ("Số liệu", "Số trong dòng chỉ số lệch gốc", "Popup nội suy THẲNG từ cấp 1 tới cấp tối đa, còn lua gốc là đường nhiều mốc (Link) -> các cấp giữa lệch. Hiện cấp đầu tiên bị lệch + số cấp lệch."),
    ("Đích", "Dòng 'Tăng sát thương kỹ năng liên kết' trỏ sai skill", ""),
    ("max_level", "Cấp tối đa khác MaxLevel", ""),
    ("weapon_limit", "Hạn chế vũ khí khác EqtLimit", ""),
    ("horse_limit", "Cưỡi ngựa khác HorseLimit", ""),
    ("Thiếu dòng gốc", "Lua gốc có thuộc tính nhưng popup không hiện", ""),
    ("Dòng không có trong gốc", "Popup có dòng mà bảng lua không có", "Phần lớn là dòng tự thêm (Thời gian duy trì, Phạm vi hiệu quả, Tốc độ xuất chiêu...) — lấy từ thành phần khác hoặc cột Skills.txt; cần xem từng dòng."),
    ("Lưu phái", "Dòng lưu phái khác gamesetting.ini", "Chữ game chép từ ảnh mẫu; gốc lấy [SkillAttrib] theo cột Attrib."),
    ("Tên", "Tên khác Skills.txt", "Phần lớn là chính tả (gốc có lỗi gõ như 'Khi Hàn', 'Tích Lịch'), vài cái game đặt tên khác hẳn."),
    ("Nhãn khác", "Nhãn dòng khác magicdesc (số khớp)", "Chỉ khác chữ, số đúng — ưu tiên thấp."),
    ("SkillId", "SkillId không có trong Skills.txt", ""),
    ("không có vltk_skill_id", "Không đối chiếu được (không có vltk_skill_id)", "Thường là skill con ẩn."),
]
md = ["# Đối chiếu hiển thị skill với nguồn gốc VLTK", "",
      "Sinh bởi `tools/audit_skill_display.py` (chỉ đọc). Không tính *Cấp học*: game hiện `ReqLevel` của Skills.txt — đúng cách client gốc hiện; `faction_def.lua` của 5 phái mới ghi cao hơn 10 cấp.", ""]
md.append("| Nhóm | Số mục |")
md.append("|---|---|")
for key, title, _ in GROUPS:
    n = sum(1 for iss in report.values() for t, k, g, e in iss if k.startswith(key))
    md.append("| %s | %d |" % (title, n))
for key, title, note in GROUPS:
    rows = [(sect, t, k, g, e) for sect, iss in report.items() for t, k, g, e in iss if k.startswith(key)]
    if not rows:
        continue
    md += ["", "## %s (%d)" % (title, len(rows))]
    if note:
        md += ["", note]
    md += ["", "| Phái | Skill | Mục | Game | Gốc |", "|---|---|---|---|---|"]
    for sect, t, k, g, e in rows:
        md.append("| %s | %s | %s | %s | %s |" % (sect, t, k.replace("|", "/"), g.replace("|", "/"), e.replace("gốc: ", "").replace("|", "/")))
out_md = REPO / "docs" / "qa_reports" / "skill_display_audit.md"
out_md.parent.mkdir(parents=True, exist_ok=True)
out_md.write_text("\n".join(md) + "\n", encoding="utf-8", newline="\n")
print("\nĐã ghi", out_md)
