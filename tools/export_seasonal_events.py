"""Xuất SỰ KIỆN NĂM (Tết, Valentine, 8/3, 30/4, Sinh nhật, Trung Thu, Quốc khánh, 20/10, 20/11, Giáng Sinh) từ source VLTK
bản 15 phái -> data/events/seasonal_events.json.

    python tools/export_seasonal_events.py

Nguồn: E:/jx15_src/script/activitysys/config/<id>/ (xem docs/vltk_seasonal_events_reference.md):
  - head.lua      : tên + ngày bắt đầu/kết thúc gốc (năm cũ) -> đổi thành độ lệch ngày quanh ngày lễ (dương / âm lịch)
  - variables.lua : hằng vật phẩm ITEM_* = {tbProp={6,1,X}, nExpiredTime=...}
  - config.lua    : tbConfig[n] — "CreateCompose" = công thức ép, "ItemScript" = dùng vật phẩm, "NpcOnDeath"/"ClickNpc"
                    (tên bước) = nguồn nguyên liệu
  - extend.lua    : hàm ThisActivity:Xxx — bảng thưởng (tbAwardTemplet:Give) + tỷ lệ thành công (CheckRandom)
Bảng thưởng giữ nguyên cấu trúc tbAwardTemplet gốc (lib/awardtemplet.lua):
  {"all": [...]}            = nhận lần lượt hết (bảng con không có nRate)
  {"pick": [{"rate": %, ...}]} = quay 1 món theo nRate (% trên 100 — tổng < 100 thì có thể trượt)
  {"item": misc_id, "count": n, "expire": {"days": n} | {"event_end": true}} / {"exp": n} / {"gold": n} / {"equip": [...]}
Chỗ hàm gốc viết tay không tự đọc được thì MANIFEST khai "override" (ghi rõ lý do).
"""
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vltk_source  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "events" / "seasonal_events.json"
CFG = vltk_source.SCRIPT / "activitysys" / "config"


def tcvn(b: bytes) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=b, capture_output=True).stdout.decode("utf-8", "replace")


# ------------------------------------------------------------------ đọc bảng lua (literal)

TOKEN = re.compile(r"""
    (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*) |
    (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*') |
    (?P<num>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?) |
    (?P<name>[A-Za-z_][A-Za-z_0-9]*(?:[.:][A-Za-z_][A-Za-z_0-9]*)*) |
    (?P<op>[{}\[\]=,;()+*/-])
""", re.S | re.X)


class Ref:
    """Tên biến chưa giải (VD ITEM_XMAS_BAG, nil...)."""
    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return "Ref(%s)" % self.name


def tokens(text):
    text = re.sub(r"%(?=[A-Za-z_])", "", text)
    out = []
    pos = 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            out.append(("op", text[pos]))
            pos += 1
            continue
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        out.append((kind, m.group(kind)))
    return out


class Parser:
    def __init__(self, toks, env):
        self.t = toks
        self.i = 0
        self.env = env

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def take(self):
        tok = self.peek()
        self.i += 1
        return tok

    def value(self):
        kind, v = self.take()
        if kind == "op" and v == "{":
            return self.table()
        if kind == "str":
            return v[1:-1].replace('\\"', '"')
        if kind == "num":
            val = float(v)
            val = int(val) if val == int(val) else val
            return self._arith(val)
        if kind == "op" and v == "-":
            return -self.value()
        if kind == "name":
            if v == "nil":
                return None
            if v in ("true", "false"):
                return v == "true"
            if self.peek() == ("op", "("):   # lời gọi hàm trong bảng -> bỏ qua đối số
                depth = 0
                while True:
                    k, x = self.take()
                    if k is None:
                        break
                    if x == "(":
                        depth += 1
                    elif x == ")":
                        depth -= 1
                        if depth == 0:
                            break
                return Ref(v + "()")
            res = self.env.get(v, Ref(v))
            while self.peek() == ("op", "["):
                save = self.i
                self.take()
                key = self.value()
                if self.peek() != ("op", "]"):
                    self.i = save
                    break
                self.take()
                if isinstance(res, dict) and key in res:
                    res = res[key]
                elif isinstance(res, list) and isinstance(key, int) and 1 <= key <= len(res):
                    res = res[key - 1]
                else:
                    res = Ref("%s[%s]" % (v, key))
            return self._arith(res) if isinstance(res, (int, float)) else res
        return Ref(str(v))

    def _arith(self, val):
        while self.peek()[0] == "op" and self.peek()[1] in "+-*/" and self.peek()[1] != "":
            op = self.take()[1]
            rhs = self.value()
            if not isinstance(rhs, (int, float)):
                return val
            val = {"+": val + rhs, "-": val - rhs, "*": val * rhs, "/": val / rhs if rhs else val}[op]
        return val

    def table(self):
        arr, d = [], {}
        while True:
            kind, v = self.peek()
            if kind is None:
                break
            if kind == "op" and v == "}":
                self.take()
                break
            if kind == "op" and v in ",;":
                self.take()
                continue
            if kind == "op" and v == "[":
                self.take()
                key = self.value()
                self.take()  # ]
                self.take()  # =
                d[key] = self.value()
            elif kind == "name" and self.peek(1) == ("op", "="):
                self.take()
                self.take()
                d[v] = self.value()
            else:
                arr.append(self.value())
        if d and not arr and all(isinstance(k, int) for k in d):
            return [d[k] for k in sorted(d)] if sorted(d) == list(range(1, len(d) + 1)) else d
        if arr and not d:
            return arr
        if arr:
            d["_arr"] = arr
        return d


def parse_value(text, env):
    return Parser(tokens(text), env).value()


def parse_assignments(text, env):
    """NAME = value ở đầu dòng (variables.lua / tbConfig[n] = {...}); NAME["k"] = value gộp vào bảng NAME."""
    out = {}
    for m in re.finditer(r'^\s*([A-Za-z_]\w*)\s*\[\s*"([^"]+)"\s*\]\s*=\s*', text, re.M):
        try:
            val = Parser(tokens(text[m.end():m.end() + 200000]), {**env, **out}).value()
        except Exception:  # noqa: BLE001
            continue
        base = out.get(m.group(1), env.get(m.group(1)))
        if not isinstance(base, dict):
            base = {}
        base[m.group(2)] = val
        out[m.group(1)] = base
    for m in re.finditer(r"^(?:local\s+)?([A-Za-z_][\w]*(?:\[\d+\])?)\s*=\s*", text, re.M):
        try:
            p = Parser(tokens(text[m.end():m.end() + 200000]), {**env, **out})
            val = p.value()
            if isinstance(out.get(m.group(1)), dict) and isinstance(val, dict):
                out[m.group(1)].update(val)
            else:
                out[m.group(1)] = val
        except Exception:  # noqa: BLE001
            continue
    return out


# ------------------------------------------------------------------ vật phẩm

def load_misc():
    misc = json.loads((ROOT / "data" / "items" / "misc_items.json").read_text(encoding="utf-8"))
    by = {}
    for it in misc:
        by[(it["genre"], it["detail"], it["particular"])] = it
    return by


MISC = load_misc()
MISC_NAME = {it["id"]: it["name"] for it in MISC.values()}
UNKNOWN = []


def misc_of(prop):
    if not isinstance(prop, list) or not prop:
        return None
    g = int(prop[0])
    if g == 6:
        it = MISC.get((6, int(prop[1]), int(prop[2])))
        return it["id"] if it else None
    if g == 4:
        it = MISC.get((4, int(prop[1]), int(prop[2]) if len(prop) > 2 else 1)) or MISC.get((4, int(prop[1]), 1))
        return it["id"] if it else None
    return None


def expire_of(v):
    """nExpiredTime gốc: YYYYMMDD = hết hạn cuối đợt sự kiện; số nhỏ = phút."""
    if not isinstance(v, (int, float)) or v <= 0:
        return None
    if v >= 20000000:
        return {"event_end": True}
    return {"days": max(1, round(v / 1440))}


def _int(v, default=0):
    return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else default


def leaf(t):
    """1 phần thưởng lá (tbAwardTemplet.TYPE gốc)."""
    if not isinstance(t, dict):
        return None
    cnt = _int(t.get("nCount", 1), 1)
    if "tbProp" in t:
        prop = t["tbProp"]
        if isinstance(prop, list) and prop and int(prop[0]) == 0:
            if len(prop) == 2 or _int(t.get("nQuality", 0)) == 1:
                out = {"gold_row": int(prop[1]), "name": t.get("szName", "")}
            else:
                out = {"equip": [int(x) for x in prop[1:4]], "name": t.get("szName", "")}
        else:
            mid = misc_of(prop)
            if mid is None:
                UNKNOWN.append(("item", prop, t.get("szName")))
                return None
            out = {"item": mid, "count": cnt}
            if isinstance(prop, list) and len(prop) > 3 and int(prop[3]) > 1:
                out["level"] = int(prop[3])
        exp = expire_of(t.get("nExpiredTime"))
        if exp:
            out["expire"] = exp
        return out
    if "nExp_tl" in t:   ## kinh nghiệm "thực" gốc: nExp_tl=1 thì lượng nằm ở nCount, không thì chính nó
        v = _int(t["nExp_tl"])
        v = v if v > 1 else cnt
        return {"exp": v} if v > 1 else None
    if "tbAward" in t:   ## {tbAward=..., szLog=...}
        return award(t["tbAward"])
    if "nExp" in t:
        return {"exp": _int(t["nExp"])} if _int(t["nExp"]) > 0 else None
    if "nJxb" in t:
        return {"gold": _int(t["nJxb"]) * cnt} if _int(t["nJxb"]) > 0 else None
    UNKNOWN.append(("leaf", {k: v for k, v in t.items() if not isinstance(v, Ref)}))
    return None


def award(t):
    """Bảng thưởng tbAwardTemplet -> cây {"all"/"pick"/lá}."""
    if isinstance(t, dict) and t and all(isinstance(k, int) for k in t):   ## bảng mốc {số lần: thưởng}
        ms = {}
        for k, v in t.items():
            a = award(v[0]) if isinstance(v, list) and len(v) == 2 and isinstance(v[1], str) else award(v)
            if a:
                ms[str(k)] = a
        return {"milestones": ms} if ms else None
    if isinstance(t, dict) and "_arr" not in t:
        lf = leaf(t)
        return lf
    if isinstance(t, list) and t:
        if isinstance(t[0], dict) and "nRate" in t[0]:
            picks = []
            for x in t:
                lf = award(x) if isinstance(x, list) else leaf(x)
                if lf is not None:
                    lf = dict(lf)
                    lf["rate"] = float(x.get("nRate", 0)) if isinstance(x, dict) else 0.0
                    picks.append(lf)
            return {"pick": picks}
        parts = [award(x) for x in t]
        parts = [p for p in parts if p]
        return parts[0] if len(parts) == 1 else {"all": parts}
    return None


# ------------------------------------------------------------------ hàm trong extend.lua

def functions(text):
    out = {}
    for m in re.finditer(r"^function\s+pActivity:(\w+)\s*\(([^)]*)\)(.*?)^end", text, re.S | re.M):
        out[m.group(1)] = m.group(3)
    return out


MILESTONE_IF = re.compile(r'\b(?:elseif|if)\s*\(?\s*self:CheckTask\(\s*\w+\s*,\s*(\d+)\s*,\s*""\s*,\s*"(?:==|<)"\s*\)(?:(?!\bend\b|\bthen\b)[\s\S]){0,200}\bthen')
BLOCK_END = re.compile(r"\n\s*(?:elseif|else|end)\b")


def split_milestones(body):
    """Tách các nhánh "if self:CheckTask(x, N, "", "==") then <thưởng>" (thưởng MỐC khi dùng tới lần thứ N) khỏi thân hàm.
    Nhánh "if tbLog[nCount + 1] then ... else <thưởng thường> end" (VD Mũ Tai Bèo) chỉ giữ phần else."""
    body = re.sub(r"\bif\s+\w+\[\s*n\w+\s*\+\s*1\s*\]\s*then.*?\n\s*else\b(.*?)\n\s*end\b", r"\1", body, flags=re.S)
    spans, out, pos = [], [], 0
    for m in MILESTONE_IF.finditer(body):
        e = BLOCK_END.search(body, m.end())
        end = e.start() if e else len(body)
        spans.append((int(m.group(1)), body[m.end():end]))
        out.append(body[pos:m.start()])
        pos = end
    out.append(body[pos:])
    return "".join(out), spans


def func_result(body, env, _nested=False):
    """Đọc phần thưởng của 1 hàm ThisActivity: tỷ lệ thành công, GetItem, AddExp, tbAwardTemplet:Give, mốc dùng."""
    milestone_spans = []
    if not _nested:
        body, milestone_spans = split_milestones(body)
    loc = dict(env)
    tables = {}
    for m in re.finditer(r"(?:local\s+|^\s*)(\w+)\s*=\s*(?!=)", body, re.M):
        rest = body[m.end():]
        try:
            v = parse_value(rest, {**loc, **tables})
        except Exception:  # noqa: BLE001
            continue
        if isinstance(v, (dict, list, int, float)) and not isinstance(v, bool):
            tables[m.group(1)] = v
    loc.update(tables)
    parts, milestones = [], {}
    rate = None
    m = re.search(r"CheckRandom\(\s*(\w+)", body)
    if m:
        r = loc.get(m.group(1))
        if r is None and m.group(1).isdigit():
            r = float(m.group(1))
        if isinstance(r, (int, float)):
            rate = float(r)
    for m in re.finditer(r"(tbAwardTemplet:Give|self:GiveItemAward|PlayerFunLib:GetItem|PlayerFunLib:AddExp|AddOwnExp)\s*\(", body):
        args = body[m.end():]
        call = m.group(1)
        if call in ("PlayerFunLib:AddExp", "AddOwnExp"):
            v = parse_value(args, loc)
            if isinstance(v, (int, float)):
                parts.append({"exp": int(v)})
            continue
        if call == "PlayerFunLib:GetItem":
            p = Parser(tokens(args), loc)
            it = p.value()
            p.take()
            n = p.value()
            lf = leaf(it) if isinstance(it, dict) else None
            if lf and isinstance(n, (int, float)) and "item" in lf:
                lf["count"] = int(n)
            if lf:
                parts.append(lf)
            continue
        nm = re.match(r"\s*([\w%]+(?:\[\s*\"[^\"]+\"\s*\])*)\s*(\[\s*n\w+\s*\])?", args)
        if not nm:
            continue
        tb = parse_value(nm.group(1), loc)
        if nm.group(2):   # tbExtAward[nCount] -> mốc theo số lần dùng
            if isinstance(tb, dict):
                for k, v in tb.items():
                    if isinstance(k, int):
                        a = award(v[0] if isinstance(v, list) and v and isinstance(v[0], dict) and "nRate" not in v[0] and len(v) == 2 and isinstance(v[1], str) else v)
                        if a:
                            milestones[str(k)] = a
            continue
        if tb is not None:
            a = award(tb)
            if a:
                parts.append(a)
    for n, span in milestone_spans:
        r, _, _ = func_result(span, loc, True)
        if r:
            milestones[str(n)] = r
    for p in list(parts):
        if isinstance(p, dict) and "milestones" in p:
            milestones.update(p["milestones"])
            parts.remove(p)
    res = parts[0] if len(parts) == 1 else ({"all": parts} if parts else None)
    return res, rate, milestones


# ------------------------------------------------------------------ manifest 10 sự kiện năm

## anchor: ngày lễ (solar = dương, lunar = âm lịch); src_anchor = ngày lễ đó ở NĂM GỐC của hoạt động (để đổi ngày gốc -> độ lệch).
## window: ghi đè ngày gốc (head.lua ghi sai/không hợp lệ). recipes/usables: chỉ lấy tbConfig nId liệt kê (None = tất cả).
MANIFEST = [
    {"id": "tet_nguyen_dan", "act": 35, "name": "Tết Nguyên Đán", "icon": "🧧", "cover": "6_1_3106",
     "calendar": "lunar", "anchor": [1, 1], "src_anchor": "2012-01-23", "extra": "newyear_2008",
     "desc": "Mừng xuân mới: mở Túi Mừng Xuân lấy Lá bánh, Gạo nếp, Đậu xanh, Thịt heo gói Bánh Chưng (thường / hảo hạng / thượng hạng), treo liễn Phúc – Lộc – Thọ hái lộc; gom năm loại trái cây bày Mâm Ngũ Quả (Mâm Bạc / Mâm Vàng), đổi Thủy Tinh – Tinh Hồng Bảo Thạch lấy Bao Lì Xì Đỏ. Ăn bánh, dùng mâm và lì xì nhận kinh nghiệm cùng bảo vật."},
    {"id": "valentine", "act": 1008, "name": "Lễ Tình Nhân 14/2", "icon": "💝",
     "calendar": "solar", "anchor": [2, 14], "src_anchor": "2012-02-14",
     "desc": "Pha Trà Giải Nhiệt và gói Quà Màu Xanh tặng người thương; nộp Hoa Hồng lấy kinh nghiệm. Dùng trà và quà nhận phần thưởng."},
    {"id": "quoc_te_phu_nu", "act": 40, "name": "Quốc tế Phụ nữ 8/3", "icon": "🌹",
     "calendar": "solar", "anchor": [3, 8], "src_anchor": "2012-03-08",
     "desc": "Gom Hoa Hồng bốn màu, Cỏ Xanh, Giỏ Đựng Hoa và Nơ để kết Hoa Hồng Tam Sắc, Tứ Sắc và Giỏ Hoa Hồng Vĩnh Cửu. Dùng hoa nhận kinh nghiệm và bảo vật quý."},
    {"id": "giai_phong_30_4", "act": 1009, "name": "Mừng Giải phóng 30/4", "icon": "🎖️", "cover": "6_1_30198",
     "calendar": "solar", "anchor": [4, 30], "src_anchor": "2012-04-30",
     "desc": "Ghép Mảnh Chiến Công thành Mũ Hòa Bình, Mũ Tai Bèo, Mũ Tự Do. Dùng mũ nhận kinh nghiệm và quà chiến thắng."},
    ## Đoan Ngọ: sự kiện kiểu cũ (không có hoạt động activitysys) — dữ liệu từ ban_banh_u.lua, khung ngày tự đặt quanh mùng 5/5 âm.
    {"id": "doan_ngo", "act": None, "name": "Tết Đoan Ngọ", "icon": "🍙", "cover": "6_1_68",
     "calendar": "lunar", "anchor": [5, 5], "window": [-6, 7], "extra": "doan_ngo", "source": "script/global/ban_banh_u.lua",
     "desc": "Mùng 5 tháng 5 tưởng nhớ Khuất Nguyên: gom Táo đỏ, Hạt dẻ, Lá bánh, Gạo nếp, Thịt heo, Thịt bò gói bánh chưng Hạt dẻ, Thịt heo, Thịt bò, Thập cẩm, May mắn; nhờ Tống tẩu nâng Thập cẩm lên Mật ong, Bát bửu, Bách quả, Thượng hạng và Bánh chưng Khuất Nguyên huyền thoại (hỏng thì trả lại Thập cẩm). Ăn bánh tăng sức hoặc nhận kinh nghiệm."},
    {"id": "sinh_nhat_vltk", "act": 31, "name": "Sinh Nhật Võ Lâm Truyền Kỳ", "icon": "🎂",
     "calendar": "solar", "anchor": [6, 15], "src_anchor": "2011-06-15",
     "desc": "Mừng sinh nhật Võ Lâm: dùng Sữa Tươi, Đường, Bột Mì, Kem, Bơ, SoCoLa, Nến làm Bánh Kem và Bánh Sinh Nhật, ghép Bánh Sinh Nhật Đặc Biệt. Ăn bánh nhận kinh nghiệm và rương quà."},
    ## Trung Thu: lồng đèn làm từ GIẤY KIẾNG theo bản 2006 (event/mid_autumn06, khung 30/9–13/10/2006 quanh rằm 06/10/2006 = −6..+7);
    ## hoạt động 21 chỉ lấy phần đổi Ngũ Hành Kỳ Thạch + Bánh Trung Thu các thành (bỏ lồng đèn làm từ bánh, mua bánh, nộp đèn).
    {"id": "trung_thu", "act": 21, "name": "Tết Trung Thu", "icon": "🏮",
     "calendar": "lunar", "anchor": [8, 15], "window": [-6, 7], "skip": [8, 11, 12, 13, 14, 28], "extra": "mid_autumn06",
     "desc": "Rằm tháng Tám: mở Hộp Vật Liệu Lồng Đèn (đánh quái rơi) lấy Giấy kiếng vàng / lam / lục / đỏ / cam, Thanh tre, Dây cói, Nến rồi làm lồng đèn bươm bướm, ngôi sao, ống, tròn, cá chép, kéo quân. Thắp đèn được nhân đôi kinh nghiệm 10–60 phút. Ăn Bánh Trung Thu các thành nhận kinh nghiệm; đổi Ngũ Hành Kỳ Thạch lấy Hồi Thiên Tái Tạo Cẩm Nang, Nhất Kỷ Càn Khôn Phù."},
    {"id": "quoc_khanh", "act": 33, "name": "Mừng Quốc khánh 2/9", "icon": "🎆",
     "calendar": "solar", "anchor": [9, 2], "src_anchor": "2011-09-02",
     "desc": "Nộp Dây Thừng, ghép Dây Thừng + Dải Lụa Đỏ thành Pháo Hoa Quốc Khánh, Nến Trắng + Lồng Đèn Ánh Trăng thành Bánh Trung Thu Hàn Nguyệt. Đốt pháo, ăn bánh nhận thưởng."},
    {"id": "phu_nu_viet_nam", "act": 1007, "name": "Phụ nữ Việt Nam 20/10", "icon": "💐",
     "calendar": "solar", "anchor": [10, 20], "src_anchor": "2011-10-20",
     "desc": "Ghép Hoàng Thạch + Thiên Tinh Thạch thành Băng Tinh Thạch; nộp Hoàng Thạch lấy kinh nghiệm. Dùng Băng Tinh Thạch nhận phần thưởng."},
    {"id": "nha_giao", "act": 30, "name": "Nhà Giáo Việt Nam 20/11", "icon": "📖",
     "calendar": "solar", "anchor": [11, 20], "src_anchor": "2011-11-20",
     "desc": "Tri ân thầy cô: ghép Giấy Trắng, Cây Bút, Lọ Mực thành Cuốn Sách. Dùng Cuốn Sách, Hoa Tri Ân, Thiên Vũ Hồn nhận kinh nghiệm và bảo vật."},
    {"id": "giang_sinh", "act": 37, "name": "Lễ Giáng Sinh", "icon": "🎄",
     "calendar": "solar", "anchor": [12, 25], "src_anchor": "2011-12-25",
     "desc": "Gom Áo, Quần, Túi, Nón Giáng Sinh ghép Hộp Quà Giáng Sinh, Ông Già Noel (nhỏ / trung / đại), Bánh Giáng Sinh, Ông Già Noel Hồng; đổi Ngôi Sao lấy lệnh bài triệu hồi Boss. Mở quà nhận kinh nghiệm và bảo vật."},
]


def extra_mid_autumn06():
    """Lồng đèn giấy kiếng Trung Thu 2006 — event/mid_autumn06:
    head.lua tab_Lightcage {đèn đặc biệt, giấy kiếng, tên, tên giấy, tiền công, đèn thường, bánh, tên bánh, số giấy} +
    tab_BasicMaterial (thanh tre, dây cói, nến 1 mỗi thứ); lightcage_of_midautumn06.lua: 80% ra đèn "đặc biệt", 20% đèn thường —
    bản 15 phái không có đèn đặc biệt (1229–1234) trong bảng vật phẩm nên cả hai ra đèn 1241–1246 (thắp = x2 kinh nghiệm, xem
    PotionEffect). Kéo quân: 1 giấy mỗi màu (1221–1225) + vật liệu cơ bản + 5000 lượng.
    item/material.lua tab_material: Hộp vật liệu lồng đèn 1220 (đánh quái rơi) mở ra 1 vật liệu theo trọng số /10000."""
    base = vltk_source.SCRIPT / "event" / "mid_autumn06"
    head = tcvn((base / "head.lua").read_bytes())
    env = parse_assignments(head, {})
    cages, basic = env["tab_Lightcage"], env["tab_BasicMaterial"]
    basic_mats = [{"item": "6_1_%d" % b[0], "count": 1} for b in basic]
    minutes = {1241: 10, 1242: 20, 1243: 30, 1244: 40, 1245: 50, 1246: 60}
    recipes = []
    for i, c in enumerate(cages):
        lamp = int(c[5]) if i < 5 else 1246
        if i < 5:
            mats = [{"item": "6_1_%d" % int(c[1]), "count": int(c[8])}] + basic_mats
        else:
            mats = [{"item": "6_1_%d" % p, "count": 1} for p in range(1221, 1226)] + basic_mats
        recipes.append({"id": "au06_%d" % (i + 1), "name": "Làm %s" % c[2], "title": c[2], "materials": mats,
                        "money": int(c[4]), "result": {"item": "6_1_%d" % lamp, "count": 1}})
    mat = tcvn((base / "item" / "material.lua").read_bytes())
    tab = parse_assignments(mat, {})["tab_material"]
    box = {"result": {"pick": [{"item": "6_1_%d" % int(r[1]), "count": 1, "expire": {"event_end": True},
                                "rate": float(r[2]) / 100.0} for r in tab]}}
    buffs = {"6_1_%d" % k: {"exp_x2_minutes": v} for k, v in minutes.items()}
    sources = {"6_1_1220": ["Đánh quái rơi Hộp vật liệu lồng đèn (mở ra giấy kiếng, thanh tre, dây cói, nến)"]}
    return recipes, {"6_1_1220": box}, buffs, sources


def _lua_table(text, name):
    """Đọc bảng Lua `<name> = { ... }` (kể cả tên có dấu chấm như tbclassname.mareial)."""
    m = re.search(re.escape(name) + r"\s*=\s*(?=\{)", text)
    if not m:
        raise KeyError(name)
    return parse_value(text[m.end():], {})


def _prop_leaf(it, count=1):
    """{G,D,P,LV,szname} gốc -> lá thưởng."""
    g, d, p = int(it["G"]), int(it["D"]), int(it["P"])
    if g == 0:
        return {"equip": [d, p, int(it.get("LV", 1))], "name": str(it.get("szname", "")).strip()}
    mid = misc_of([g, d, p])
    if mid is None:
        UNKNOWN.append(("item", [g, d, p], it.get("szname")))
        return None
    out = {"item": mid, "count": count}
    if int(it.get("LV", 1)) > 1:
        out["level"] = int(it["LV"])
    return out


def extra_newyear_2008():
    """Tết 2008 — gói bánh chưng (event/newyear_2008, item/newyear_2008/makezongzi), gộp vào thẻ Tết Nguyên Đán.
    zaozongbing/head.lua tb_Mareial: 3 loại bánh (4 Lá bánh + 3 Gạo nếp + 2 Đậu xanh + 1 Thịt heo [+ Bí quyết]); zongzi.lua: ăn bánh
    ra kinh nghiệm + 1 món ngẫu nhiên (prob / 100); yingchundai.lua: Túi mừng xuân (quái rơi) mở ra 1 nguyên liệu; cailu: treo liễn
    Phúc + Lộc + Thọ (9.999 lượng, tối đa 20 lần) ra Phúc Duyên Lộ / Tiên Thảo Lộ + kinh nghiệm ngẫu nhiên.
    Bí quyết 1660/1661: gốc VNG không có nguồn rơi (chỉ NPC thử nghiệm phát) -> TỰ THÊM vào Túi mừng xuân (thượng hạng 0,5%,
    hảo hạng 1%, bớt từ Lá bánh) để bánh thượng / hảo hạng làm được."""
    base = vltk_source.SCRIPT / "event" / "newyear_2008"
    item = vltk_source.SCRIPT / "item" / "newyear_2008" / "makezongzi"
    head = tcvn((base / "zaozongbing" / "head.lua").read_bytes())
    mats = _lua_table(head, "tbclassname.tb_Mareial")
    recipes = []
    titles = {1: "thượng hạng", 2: "hảo hạng", 3: "thường"}
    for i in (1, 2, 3):
        rows = mats["select%d" % i]
        prod = rows[0]
        recipes.append({"id": "tt08_%d" % i, "name": "Gói %s" % str(prod["szname"]).strip(), "title": str(prod["szname"]).strip(),
                        "materials": [{"item": misc_of([int(r["G"]), int(r["D"]), int(r["P"])]), "count": int(r["num"])} for r in rows[1:]],
                        "money": int(prod.get("nMoney", 0)), "result": {"item": "6_1_%d" % int(prod["P"]), "count": 1}})
    cailu = tcvn((base / "cailu" / "chunjiecailu.lua").read_bytes())
    lien = _lua_table(cailu, "NewYear2008_cailu.mareial")
    pots = _lua_table(cailu, "NewYear2008_cailu.randomitem")
    exps = _lua_table(cailu, "NewYear2008_cailu.randomnexp")
    hand = int(re.search(r"NewYear2008_cailu\.handcash\s*=\s*(\d+)", cailu).group(1))
    times = int(re.search(r"NewYear2008_cailu\.ntasksum\s*=\s*(\d+)", cailu).group(1))
    pick_pot = [dict(_prop_leaf(x), rate=float(x["prop"])) for x in pots["nitem"]]
    pick_exp = [{"exp": int(x["nexp"]), "rate": float(x["prop"])} for x in exps["nexp"]]
    recipes.append({"id": "tt08_lien", "name": "Treo liễn Phúc Lộc Thọ", "title": "Treo liễn Phúc Lộc Thọ",
                    "materials": [{"item": misc_of([int(x["G"]), int(x["D"]), int(x["P"])]), "count": 1} for x in lien],
                    "money": hand, "limit": times, "result": {"all": [{"pick": pick_pot}, {"pick": pick_exp}]}})
    zz = tcvn((item / "zongzi.lua").read_bytes())
    usables = {}
    for z in _lua_table(zz, "tbclassname.mareial")["tbitem"]:
        parts = [{"exp": int(z["nexp"])}]
        if "tbrandomitem" in z:
            ri = z["tbrandomitem"]
            parts.append({"pick": [dict(_prop_leaf(x), rate=float(x["prob"])) for x in ri["tbitem"] if _prop_leaf(x)]})
        usables["6_1_%d" % int(z["P"])] = {"result": parts[0] if len(parts) == 1 else {"all": parts}, "min_level": 50}
    bag = tcvn((item / "yingchundai.lua").read_bytes())
    picks = [dict(_prop_leaf(x), rate=float(x["prob"])) for x in _lua_table(bag, "tbclassname.mareial")["tbitem"]]   ## gốc không đặt hạn
    picks[0]["rate"] = round(picks[0]["rate"] - 1.5, 2)          ## tự thêm Bí quyết (xem docstring)
    picks += [{"item": "6_1_1660", "count": 1, "rate": 0.5}, {"item": "6_1_1661", "count": 1, "rate": 1.0}]
    usables["6_1_1652"] = {"result": {"pick": picks}}
    sources = {"6_1_1652": ["Đánh quái rơi Túi mừng xuân (mở ra Lá bánh, Gạo nếp, Đậu xanh, Thịt heo, Phúc / Lộc / Thọ, Bí quyết)"]}
    return recipes, usables, {}, sources


## Đoan Ngọ — Tống tẩu (script/global/ban_banh_u.lua, kiểu cũ: nguyên liệu là vật phẩm nhiệm vụ 4_394..4_405).
DN_TAO, DN_HAT_DE, DN_LA, DN_GAO, DN_HEO, DN_BO, DN_MAT_PHUONG, DN_GAO_MAY_MAN = (
    "4_394_1", "4_395_1", "4_396_1", "4_397_1", "4_398_1", "4_399_1", "4_404_1", "4_405_1")


def extra_doan_ngo():
    """make()/yes1..6: bánh Hạt dẻ / Thịt heo / Thịt bò (2 mỗi nguyên liệu + 2.000), Thập cẩm (2 mỗi thứ của 6 nguyên liệu, 30%
    thành công, hỏng mất hết), May mắn (1 mỗi thứ + Gạo nếp may mắn). skill()/yes7..11: nâng Thập cẩm -> Mật ong -> Bát bửu ->
    Bách quả -> Thượng hạng -> Khuất Nguyên, mỗi lần 1.000 lượng + 1 nguyên liệu bất kỳ (gốc lấy món đầu tiên có trong túi theo thứ
    tự 394..399); tỷ lệ Shijin2mijian.. (50/30/30/30/3), có Khuất Nguyên Mật phương cộng 10/20/10/5/3 (mất Mật phương); hỏng thì
    nhận lại Bánh chưng Thập cẩm. Bỏ: bánh Nhân táo (vật phẩm loại 1_7_0 không có trong bảng), Thượng hạng thành công trừ thêm
    thịt heo + thịt bò nếu có (gốc không bắt buộc). Ăn bánh: shijin01..06.lua (kinh nghiệm, Khuất Nguyên 200 triệu = 1 lần);
    bánh Hạt dẻ / Thịt heo / Thịt bò / May mắn là buff skill 401..404 — xem PotionEffect."""
    src = tcvn((vltk_source.SCRIPT / "global" / "ban_banh_u.lua").read_bytes())
    base_rate = {k: int(re.search(k + r"\s*=\s*(\d+)", src).group(1))
                 for k in ("Shijin2mijian", "Mijian2babao", "Babao2baiguo", "Baiguo2shuijing", "Shuijing2quyuan")}
    bonus = {k: int(m) for k, m in re.findall(r"temp\s*=\s*(\w+)\s*\+\s*(\d+)", src)}
    make = 2000
    two = lambda *ids: [{"item": i, "count": 2} for i in ids]   # noqa: E731
    recipes = [
        {"id": "dn_hat_de", "name": "Làm Bánh chưng Hạt dẻ", "materials": two(DN_HAT_DE, DN_LA, DN_GAO), "money": make,
         "result": {"item": "6_0_60", "count": 1}},
        {"id": "dn_heo", "name": "Làm Bánh chưng Thịt heo", "materials": two(DN_HAT_DE, DN_LA, DN_GAO, DN_HEO), "money": make,
         "result": {"item": "6_0_61", "count": 1}},
        {"id": "dn_bo", "name": "Làm Bánh chưng Thịt bò", "materials": two(DN_TAO, DN_LA, DN_GAO, DN_BO), "money": make,
         "result": {"item": "6_0_62", "count": 1}},
        {"id": "dn_thap_cam", "name": "Làm Bánh chưng Thập cẩm", "materials": two(DN_TAO, DN_HAT_DE, DN_LA, DN_GAO, DN_HEO, DN_BO),
         "money": make, "rate": 30.0, "result": {"item": "6_1_63", "count": 1}},
        {"id": "dn_may_man", "name": "Làm Bánh chưng May mắn",
         "materials": [{"item": i, "count": 1} for i in (DN_TAO, DN_HAT_DE, DN_LA, DN_GAO_MAY_MAN, DN_GAO, DN_HEO, DN_BO)],
         "money": make, "result": {"item": "6_0_70", "count": 1}},
    ]
    chain = [("Shijin2mijian", 63, 64), ("Mijian2babao", 64, 65), ("Babao2baiguo", 65, 66), ("Baiguo2shuijing", 66, 67),
             ("Shuijing2quyuan", 67, 68)]
    anyone = {"any": [DN_TAO, DN_HAT_DE, DN_LA, DN_GAO, DN_HEO, DN_BO], "count": 1}
    for mp in (False, True):
        for k, a, b in chain:
            mats = [{"item": "6_1_%d" % a, "count": 1}, dict(anyone)]
            if mp:
                mats.append({"item": DN_MAT_PHUONG, "count": 1})
            name = MISC_NAME.get("6_1_%d" % b, "").replace("Bánh chưng ", "")
            recipes.append({"id": "dn_up%d%s" % (b, "_mp" if mp else ""), "name": "Nâng lên %s%s" % (name, " (có Mật phương)" if mp else ""),
                            "materials": mats, "money": 1000, "rate": float(base_rate[k] + (bonus[k] if mp else 0)),
                            "result": {"item": "6_1_%d" % b, "count": 1}, "fail_result": {"item": "6_1_63", "count": 1}})
    exp = {}
    for i, p in enumerate(range(63, 69), 1):
        t = tcvn((vltk_source.SCRIPT / "item" / ("shijin%02d.lua" % i)).read_bytes())
        exp["6_1_%d" % p] = int(re.search(r"AddOwnExp\((\d+)\)", t).group(1))
    usables = {mid: {"result": {"exp": v}} for mid, v in exp.items()}
    usables["6_1_68"]["limit"] = 1   ## gốc: ăn Khuất Nguyên xong vượt trần 20 triệu -> không ăn được bánh Thập cẩm nào nữa
    buffs = {"6_0_60": {"text": "10 phút tốc độ đánh và ra chiêu +20%"},
             "6_0_61": {"text": "10 phút sinh lực và nội lực tối đa +100%"},
             "6_0_62": {"text": "10 phút kháng tất cả +5%"},
             "6_0_70": {"text": "30 phút may mắn +30"}}
    sources = {DN_TAO: ["Đánh quái rơi (gốc không còn script rơi — hiện lấy qua GM)"],
               DN_MAT_PHUONG: ["Gốc: Tống tẩu nói Mật phương đã thất lạc, không có nguồn — hiện lấy qua GM"],
               DN_GAO_MAY_MAN: ["Gốc: nhận ở Tống tẩu bằng điểm nạp — hiện lấy qua GM"]}
    return recipes, usables, buffs, sources


EXTRAS = {"mid_autumn06": extra_mid_autumn06, "newyear_2008": extra_newyear_2008, "doan_ngo": extra_doan_ngo}


def parse_date(v):
    s = str(int(v))
    return date(int(s[0:4]), int(s[4:6]), int(s[6:8]))


def build_event(man):
    files = {}
    if man.get("act") is not None:
        d = CFG / str(man["act"])
        files = {f.name: tcvn(f.read_bytes()) for f in d.glob("*.lua")}
    env = {}
    env.update(parse_assignments(files.get("variables.lua", ""), env))
    head = files.get("head.lua", "")
    m1 = re.search(r"nStartDate\s*=\s*(\d+)", head)
    m2 = re.search(r"nEndDate\s*=\s*(\d+)", head)
    if "window" in man:
        start_off, end_off = man["window"]
    else:
        anchor = date.fromisoformat(man["src_anchor"])
        start_off = (parse_date(int(m1.group(1)) // 10000) - anchor).days
        end_off = (parse_date(int(m2.group(1)) // 10000) - anchor).days - 1   # nEndDate 0:00 = hết ngày hôm trước
    funcs = {}
    for fname, text in files.items():
        if fname not in ("config.lua", "head.lua", "registe.lua"):
            funcs.update(functions(text))
    for text in files.values():   ## hằng khai trong file khác (VD local tbX ở đầu consume.lua)
        for k, v in parse_assignments(text, env).items():
            if k not in env and not isinstance(v, Ref):
                env[k] = v
    conf = files.get("config.lua", "")
    blocks = {}
    for m in re.finditer(r"^tbConfig\[(\d+)\]\s*=", conf, re.M):
        try:
            blocks[int(m.group(1))] = parse_value(conf[m.end():], env)
        except Exception as e:  # noqa: BLE001
            print("  ! không đọc được tbConfig[%s] hoạt động %s: %s" % (m.group(1), man["act"], e))
    recipes, usables, sources, warn = [], {}, {}, []

    def actions_result(actions):
        parts, rate, miles = [], None, {}
        for a in actions or []:
            if not isinstance(a, list) or not a:
                continue
            fn, args = a[0], (a[1] if len(a) > 1 else [])
            args = args if isinstance(args, list) else [args]
            if fn == "PlayerFunLib:GetItem":
                lf = leaf(args[0]) if args and isinstance(args[0], dict) else None
                if lf and len(args) > 1 and isinstance(args[1], (int, float)) and "item" in lf:
                    lf["count"] = int(args[1])
                if lf:
                    parts.append(lf)
            elif fn == "PlayerFunLib:AddExp":
                if args and isinstance(args[0], (int, float)):
                    parts.append({"exp": int(args[0])})
            elif fn == "PlayerFunLib:GetAward" or fn == "tbAwardTemplet:Give":
                a2 = award(args[0]) if args else None
                if a2:
                    parts.append(a2)
            elif fn.startswith("ThisActivity:"):
                name = fn.split(":")[1]
                if name in ("AddTask", "AddTaskDaily", "CheckTask", "CheckTaskDaily", "SetTask"):
                    continue
                body = funcs.get(name)
                if body is None:
                    warn.append("không thấy hàm %s" % name)
                    continue
                r, rt, ms = func_result(body, env)
                if r:
                    parts.append(r)
                elif not ms:
                    warn.append("hàm %s không có phần thưởng đọc được" % name)
                if rt is not None:
                    rate = rt
                miles.update(ms)
        res = parts[0] if len(parts) == 1 else ({"all": parts} if parts else None)
        return res, rate, miles

    for nid in sorted(blocks):
        b = blocks[nid]
        if not isinstance(b, dict):
            continue
        typ = b.get("szMessageType")
        if man.get("skip") and nid in man["skip"]:
            continue
        if typ == "CreateCompose":
            mats, money = [], 0
            ok = True
            for c in b.get("tbCondition") or []:
                if not isinstance(c, list) or c[0] != "AddOneMaterial":
                    continue
                nm, spec, cnt = c[1][0], c[1][1], c[1][2]
                if isinstance(spec, dict) and "nJxb" in spec:
                    money += int(spec["nJxb"]) * int(cnt)
                    continue
                mid = misc_of(spec.get("tbProp")) if isinstance(spec, dict) else None
                if mid is None:
                    warn.append("công thức %s: nguyên liệu %s không rõ" % (b.get("szName"), nm))
                    ok = False
                    continue
                mats.append({"item": mid, "count": int(cnt)})
            res, rate, miles = actions_result(b.get("tbActition"))
            if not ok or res is None or (not mats and not money):
                warn.append("bỏ công thức %s (nguyên liệu/kết quả không đủ)" % b.get("szName"))
                continue
            param = b.get("tbMessageParam") or []
            title = param[0] if param and isinstance(param[0], str) and param[0] else b.get("szName", "")
            title = re.sub(r"<[^>]+>", "", title).strip() or b.get("szName", "")
            name = b.get("szName", "") or title
            if not re.search(r"[À-ỹ]", name):   ## tên gốc tiếng Anh (VD "compose 4 color rose") -> tên hiển thị tiếng Việt
                if title and re.search(r"[À-ỹ]", title):
                    name = ("Mua " if not mats else "Hợp thành ") + title
                elif mats:
                    name = "Nộp " + MISC_NAME.get(mats[0]["item"], "vật phẩm")
            r = {"id": "c%d" % nid, "name": name, "title": title, "materials": mats, "money": money, "result": res}
            if rate is not None and rate < 100:
                r["rate"] = rate
            if miles:
                r["milestones"] = miles
            recipes.append(r)
        elif typ == "ItemScript":
            param = b.get("tbMessageParam") or []
            spec = param[0] if param else None
            if isinstance(spec, str):     # "return {tbProp=...}"
                mm = re.search(r"tbProp\s*=\s*\{([^}]*)\}", spec)
                spec = {"tbProp": [int(x) for x in mm.group(1).split(",")]} if mm else None
            mid = misc_of(spec.get("tbProp")) if isinstance(spec, dict) else None
            if mid is None:
                warn.append("ItemScript %s: vật phẩm không rõ" % b.get("szName"))
                continue
            res, _, miles = actions_result(b.get("tbActition"))
            if res is None:
                warn.append("ItemScript %s: không có phần thưởng" % b.get("szName"))
                continue
            u = {"result": res}
            if miles:
                u["milestones"] = miles
            lv = 0
            for c in b.get("tbCondition") or []:
                if isinstance(c, list) and c[0] == "PlayerFunLib:CheckTotalLevel" and isinstance(c[1], list):
                    lv = int(c[1][0])
                if isinstance(c, list) and c[0] in ("ThisActivity:CheckTask", "PlayerFunLib:CheckTask") and isinstance(c[1], list) \
                        and len(c[1]) > 3 and c[1][3] == "<" and isinstance(c[1][1], (int, float)):
                    u["limit"] = int(c[1][1])
            if lv:
                u["min_level"] = lv
            usables[mid] = u
        elif typ in ("NpcOnDeath", "ClickNpc", "FinishSongJin", "Chuanguan", "FinishKillerBoss", "YDBZguoguan", "OnLogin"):
            name = b.get("szName", "")
            for a in b.get("tbActition") or []:
                if isinstance(a, list) and a and a[0] in ("NpcFunLib:DropSingleItem", "PlayerFunLib:GetItem", "NpcFunLib:DropItem") \
                        and isinstance(a[1], list) and a[1] and isinstance(a[1][0], dict):
                    mid = misc_of(a[1][0].get("tbProp"))
                    ## tên bước gốc: bỏ tên tiếng Trung (đọc ra chữ lỗi) và tên log tiếng Anh
                    if not name or re.search(r"[^\x20-\x7e]{3}", name) or (re.fullmatch(r"[A-Za-z_ 0-9<>=.]+", name) and " " not in name.strip()) or re.match(r"(?:finish|songjin|chuangguan|fengling|kill)", name):
                        continue
                    if mid and name not in sources.setdefault(mid, []):
                        sources[mid].append(name)
    buffs = {}
    if man.get("extra"):
        x_rec, x_use, buffs, x_src = EXTRAS[man["extra"]]()
        recipes = x_rec + recipes
        usables.update(x_use)
        for k, v in x_src.items():
            sources.setdefault(k, []).extend(v)
    ev = {k: man[k] for k in ("id", "name", "icon", "calendar", "anchor", "desc")}
    if man.get("cover"):
        ev["cover"] = man["cover"]   ## ảnh đại diện thẻ (mặc định UI lấy thành phẩm công thức đầu)
    if buffs:
        ev["buff_items"] = buffs   ## đồ dùng qua PotionEffect (thắp đèn x2 kinh nghiệm) — chỉ để hiện trong Hướng dẫn
    ev.update({"start_offset": start_off, "end_offset": end_off, "source": man.get("source") or "script/activitysys/config/%d" % man["act"],
               "recipes": recipes, "usables": usables, "material_sources": sources})
    return ev, warn


## ---- Hộp sự kiện: trong đợt, MỌI quái rơi hộp (BOX_DROP_RATE / lần hạ quái); mở ra 1 nguyên liệu ngẫu nhiên của sự kiện.
## Mọi sự kiện tạm dùng chung ảnh Hộp quà trắng (baise_lipinhe — thành phẩm ép Lễ Tình Nhân, source spr/item/script/baise_lipinhe.spr);
## sau này đổi ảnh riêng từng sự kiện: thêm vào BOX_ICON.
BOX_DROP_RATE = 0.1                 ## 10% mỗi lần hạ quái (chỉ online)
BOX_ICON_DEFAULT = "baise_lipinhe"
BOX_ICON = {}                       ## event_id -> tên ảnh riêng (assets/items/icons/<tên>.png), mặc định BOX_ICON_DEFAULT
## Độ hiếm nguyên liệu trong hộp: hệ số mỗi bậc; tỷ lệ 1 món = hệ số bậc × số cái công thức cần (tối đa BOX_NEED_CAP) rồi quy
## về 100% — cùng bậc thì món cần nhiều ra nhiều hơn (VD gói bánh chưng 4 Lá : 3 Gạo : 2 Đậu : 1 Thịt, khớp Túi mừng xuân gốc).
BOX_TIER_WEIGHT = {"thuong": 10.0, "hoi_hiem": 4.0, "hiem": 1.2, "rat_hiem": 0.25}
BOX_TIER_NAME = {"thuong": "Thường", "hoi_hiem": "Hơi hiếm", "hiem": "Hiếm", "rat_hiem": "Rất hiếm"}
BOX_NEED_CAP = 5
## Bậc hiếm từng nguyên liệu (món không ghi = "thuong"). Nguyên tắc: nguyên liệu nền làm món cơ bản = Thường; món phụ / làm bản
## tốt hơn = Hơi hiếm; món chỉ dùng cho thành phẩm cao cấp = Hiếm; bí quyết / bảo vật = Rất hiếm.
BOX_TIERS = {
    "tet_nguyen_dan": {   ## Lá bánh, Gạo nếp, Đậu xanh, Thịt heo, 10 loại trái cây: Thường
        "6_1_3103": "hoi_hiem",                                     ## Mâm Bạc
        "6_1_3104": "hiem",                                         ## Mâm Vàng
        "6_1_1657": "hiem", "6_1_1658": "hiem", "6_1_1659": "hiem",  ## Phúc / Lộc / Thọ (treo liễn)
        "6_1_1661": "hiem",                                         ## Bí quyết bánh chưng hảo hạng
        "6_1_1660": "rat_hiem",                                     ## Bí quyết bánh chưng thượng hạng
    },
    "valentine": {"6_1_30176": "hoi_hiem"},                         ## Thanh Thành Tuyết Nha
    "quoc_te_phu_nu": {"6_1_3126": "hiem"},                         ## Nơ Cột Bó Hoa (chỉ Giỏ Hoa Hồng Vĩnh Cửu)
    "giai_phong_30_4": {"6_1_30200": "hoi_hiem"},                   ## Túi mừng chiến thắng
    "doan_ngo": {"4_405_1": "hiem", "4_404_1": "rat_hiem"},         ## Gạo nếp may mắn, Khuất Nguyên Mật phương
    "sinh_nhat_vltk": {"6_1_2854": "hoi_hiem", "6_1_2856": "hoi_hiem",   ## SoCoLa, Kem
                       "6_1_2857": "hiem", "6_1_2858": "hiem"},           ## Nến Sinh Nhật, Giỏ Trái Cây
    "trung_thu": {"6_1_1222": "hoi_hiem", "6_1_1223": "hiem", "6_1_1224": "hiem",   ## giấy kiếng lam / lục / đỏ
                  "6_1_1225": "rat_hiem"},                                          ## giấy kiếng cam (gốc 0,15%)
    "quoc_khanh": {"6_1_2977": "hoi_hiem", "6_1_2978": "hoi_hiem"},  ## Dải Lụa Đỏ, Lồng Đèn Ánh Trăng
    "phu_nu_viet_nam": {"6_1_30154": "hoi_hiem"},                   ## Thiên Tinh Thạch
    "nha_giao": {"6_1_3041": "hoi_hiem"},                           ## Lọ Mực
    "giang_sinh": {"6_1_3076": "hoi_hiem", "6_1_30166": "hiem"},    ## Túi Giáng Sinh, Bánh bí đỏ
}
## Vật phẩm chung (đá quý, thuốc...) dùng làm nguyên liệu nhưng không phải đồ sự kiện -> không cho vào hộp.
BOX_EXCLUDE = {"4_353_1", "4_238_1", "4_239_1", "4_240_1", "6_1_122", "6_1_123", "6_1_124", "6_1_2125"}


def _res_items(node, out):
    if isinstance(node, dict):
        if "item" in node:
            out.add(node["item"])
        for k in ("all", "pick"):
            for c in node.get(k, []):
                _res_items(c, out)


def build_box(ev):
    """Hộp sự kiện của `ev`: thêm vào ev["usables"] + trả bản ghi vật phẩm (ItemDatabase nạp từ "boxes").
    Nội dung = nguyên liệu gốc của sự kiện (món công thức cần mà không do công thức / đồ dùng nào khác của sự kiện ra — trừ túi
    nguyên liệu gốc: món túi quay ra vẫn tính), tỷ lệ theo bậc hiếm BOX_TIERS."""
    box_id = "ev_box_" + ev["id"]
    made = set()
    for r in ev["recipes"]:
        _res_items(r["result"], made)
    mats = set()
    for r in ev["recipes"]:
        for m in r["materials"]:
            mats.update(m.get("any") or [m["item"]])
    for u in ev["usables"].values():   ## đồ dùng ra TOÀN nguyên liệu = túi nguyên liệu gốc -> món của nó vẫn vào hộp
        res = u["result"]
        is_bag = isinstance(res, dict) and res.get("pick") and all(x.get("item") in mats for x in res["pick"])
        if not is_bag:
            _res_items(res, made)
    need = {}
    for r in ev["recipes"]:
        for m in r["materials"]:
            for mid in m.get("any") or [m["item"]]:
                if mid not in made and mid not in BOX_EXCLUDE:
                    need[mid] = max(need.get(mid, 0), min(int(m["count"]), BOX_NEED_CAP))
    tiers = BOX_TIERS.get(ev["id"], {})
    for mid in tiers:
        assert mid in need, "BOX_TIERS %s: %s không phải nguyên liệu của hộp" % (ev["id"], mid)
    w = {mid: BOX_TIER_WEIGHT[tiers.get(mid, "thuong")] * n for mid, n in need.items()}
    tot = sum(w.values())
    picks = {mid: v * 100.0 / tot for mid, v in w.items()}
    order = sorted(picks, key=lambda k: -picks[k])
    ev["usables"][box_id] = {"result": {"pick": [{"item": mid, "count": 1, "rate": round(picks[mid], 2),
                                                  "tier": BOX_TIER_NAME[tiers.get(mid, "thuong")]} for mid in order]}}
    ev["drop_box"] = box_id
    return box_id, {"id": box_id, "name": "Hộp %s" % ev["name"], "icon": BOX_ICON.get(ev["id"], BOX_ICON_DEFAULT), "event": ev["id"],
                    "intro": "Rơi từ quái trong thời gian %s. Mở ra 1 nguyên liệu ngẫu nhiên của sự kiện." % ev["name"],
                    "price": 0, "stack": 100, "width": 1, "height": 1, "source": "event"}


## ---- Trang bị thưởng phải có trong bảng trang bị của game (data/items/equipment.json) — ItemGenerator.generate trả null với món
## không có (VD mặt nạ sự kiện gốc: Đầu ông địa 201, Nguyên soái 447, Vương Giả, Quỷ ảnh 455...) -> người chơi mất đồ mà không nhận
## gì. Bỏ các lá đó: nhóm quay ngẫu nhiên chia lại tỷ lệ cho món còn lại (giữ nguyên phần "trượt" nếu tổng gốc < 100); công thức /
## mốc chỉ ra món không có thì bỏ.
def _equip_bases():
    eq = json.loads((ROOT / "data" / "items" / "equipment.json").read_text(encoding="utf-8"))
    arr = eq if isinstance(eq, list) else (eq.get("items") or eq.get("bases") or [])
    return {(int(x["detail"]), int(x["particular"])) for x in arr if isinstance(x, dict) and "detail" in x and "particular" in x}


EQUIP_BASES = None


def _prune_equip(node, dropped):
    """Trả node đã bỏ trang bị không có trong game (None nếu không còn gì)."""
    global EQUIP_BASES
    if EQUIP_BASES is None:
        EQUIP_BASES = _equip_bases()
    if not isinstance(node, dict):
        return node
    if "equip" in node:
        e = node["equip"]
        if (int(e[0]), int(e[1])) not in EQUIP_BASES:
            dropped.append(node.get("name") or "trang bị %d/%d" % (int(e[0]), int(e[1])))
            return None
        return node
    if "pick" in node:
        total = sum(float(c.get("rate", 0)) for c in node["pick"])
        keep = []
        for c in node["pick"]:
            k = _prune_equip(c, dropped)
            if k is not None:
                keep.append(k)
        if not keep:
            return None
        left = sum(float(c.get("rate", 0)) for c in keep)
        if left > 0 and left < total:
            for c in keep:
                c["rate"] = round(float(c["rate"]) * total / left, 4)
        out = dict(node)
        out["pick"] = keep
        return out
    if "all" in node:
        keep = [k for k in (_prune_equip(c, dropped) for c in node["all"]) if k is not None]
        if not keep:
            return None
        out = dict(node)
        out["all"] = keep
        return out
    return node


def prune_missing_equip(ev):
    dropped = []
    recipes = []
    for r in ev["recipes"]:
        res = _prune_equip(r["result"], dropped)
        if res is None:
            dropped.append("công thức " + r["name"])
            continue
        r["result"] = res
        if r.get("milestones"):
            r["milestones"] = {k: v2 for k, v2 in ((k, _prune_equip(v, dropped)) for k, v in r["milestones"].items()) if v2 is not None}
        recipes.append(r)
    ev["recipes"] = recipes
    for mid in list(ev["usables"]):
        u = ev["usables"][mid]
        res = _prune_equip(u["result"], dropped)
        if res is None:
            dropped.append("đồ dùng " + mid)
            del ev["usables"][mid]
            continue
        u["result"] = res
        if u.get("milestones"):
            u["milestones"] = {k: v2 for k, v2 in ((k, _prune_equip(v, dropped)) for k, v in u["milestones"].items()) if v2 is not None}
    return dropped


## Nguyên liệu sự kiện + hộp chồng tối đa EVENT_STACK (nhiều món gốc stack 0/50) — ItemDatabase nâng "stack" theo "stack_items".
EVENT_STACK = 100


def stack_items(events, boxes):
    ids = set(boxes)
    for ev in events:
        for r in ev["recipes"]:
            for m in r["materials"]:
                ids.update(m.get("any") or [m["item"]])
        for x in ev["usables"][ev["drop_box"]]["result"]["pick"]:
            ids.add(x["item"])
    return sorted(i for i in ids if i not in BOX_EXCLUDE)


def main():
    events = []
    boxes = {}
    for man in MANIFEST:
        ev, warn = build_event(man)
        for x in prune_missing_equip(ev):
            warn.append("bỏ (game chưa có): " + x)
        bid, brec = build_box(ev)
        boxes[bid] = brec
        print("%-18s %2d công thức, %2d vật phẩm dùng được, %+d..%+d ngày" % (ev["id"], len(ev["recipes"]), len(ev["usables"]),
                                                                          ev["start_offset"], ev["end_offset"]))
        for w in warn:
            print("   - " + w)
        events.append(ev)
    if UNKNOWN:
        print("Không đổi được %d mục thưởng (bỏ qua):" % len(UNKNOWN))
        for u in UNKNOWN[:40]:
            print("   ", u)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"version": 1, "box_drop_rate": BOX_DROP_RATE, "boxes": boxes, "event_stack": EVENT_STACK,
                               "stack_items": stack_items(events, boxes), "events": events}, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")
    print("Đã ghi", OUT)


if __name__ == "__main__":
    main()
