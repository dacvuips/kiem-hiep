import json
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
SRC_BASE = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server")
ICONV_EXE = r"C:\Program Files\Git\usr\bin\iconv.exe"

def iconv(path: Path) -> str:
    res = subprocess.run([ICONV_EXE, "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True)
    return res.stdout.decode("utf-8", "replace")

wudang_lua = iconv(SRC_BASE / "script" / "skill" / "wudang.lua")
skills_txt = iconv(SRC_BASE / "settings" / "Skills.txt").splitlines()
sk_header = [h.strip() for h in skills_txt[0].split("\t")]
sk_col = {h: i for i, h in enumerate(sk_header)}
skills_txt_map = {}
for line in skills_txt[1:]:
    p = line.split("\t")
    if len(p) > sk_col["SkillId"] and p[sk_col["SkillId"]].strip().isdigit():
        sid = int(p[sk_col["SkillId"]].strip())
        skills_txt_map[sid] = {h: p[sk_col[h]].strip() if len(p) > sk_col[h] else "" for h in sk_header if h in sk_col}

# Parse vo_dang.tres
ROOT = Path(__file__).resolve().parent.parent
tres_content = (ROOT / "systems/sect/data/vo_dang.tres").read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

stat_lines_map = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        min1 = re.search(r'min_at_level_1 = ([\d\.\-]+)', body)
        minmax = re.search(r'min_at_max_level = ([\d\.\-]+)', body)
        max1 = re.search(r'max_at_level_1 = ([\d\.\-]+)', body)
        maxmax = re.search(r'max_at_max_level = ([\d\.\-]+)', body)
        suffix = re.search(r'suffix = "([^"]*)"', body)
        target = re.search(r'target_skill_id = "([^"]+)"', body)
        stat_lines_map[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vmax": float(vmax.group(1)) if vmax else 0.0,
            "min1": float(min1.group(1)) if min1 else None,
            "minmax": float(minmax.group(1)) if minmax else None,
            "max1": float(max1.group(1)) if max1 else None,
            "maxmax": float(maxmax.group(1)) if maxmax else None,
            "suffix": suffix.group(1) if suffix else "",
            "target": target.group(1) if target else ""
        }

tres_skills = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        v_id = re.search(r'vltk_skill_id = (\d+)', body)
        req = re.search(r'req_level = (\d+)', body)
        max_l = re.search(r'max_level = (\d+)', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        tres_skills[sid] = {
            "id": sid,
            "name": name,
            "vltk_id": int(v_id.group(1)) if v_id else 0,
            "req_level": int(req.group(1)) if req else 0,
            "max_level": int(max_l.group(1)) if max_l else 20,
            "lines": [stat_lines_map.get(sl, {}) for sl in lines if sl in stat_lines_map]
        }

print("=== SO SÁNH SYNERGY CỦA WUDANG.LUA VÀ VO_DANG.TRES ===")
synergy_table = [
    # (source_skill_id, tres_id, synergy_num, target_vid, target_tres_id, target_name)
    (153, "vo_dang_no_loi_chi", 1, 365, "vo_dang_thien_dia_vo_cuc", "Thiên Địa Vô Cực"),
    (153, "vo_dang_no_loi_chi", 2, 165, "vo_dang_vo_nga_vo_kiem", "Vô Ngã Vô Kiếm"),
    (153, "vo_dang_no_loi_chi", 3, 1078, "vo_dang_tao_hoa_thai_thanh", "Tạo Hóa Thái Thanh"),
    
    (155, "vo_dang_thuong_hai_minh_nguyet", 1, 368, "vo_dang_nhan_kiem_hop_nhat", "Nhân Kiếm Hợp Nhất"),
    (155, "vo_dang_thuong_hai_minh_nguyet", 2, 267, "vo_dang_tam_hoan_thao_nguyet", "Tam Hoàn Thao Nguyệt"),
    (155, "vo_dang_thuong_hai_minh_nguyet", 3, 1079, "vo_dang_kiem_thuy_tinh_ha", "Kiếm Thùy Tinh Hà"),
    
    (158, "vo_dang_kiem_phi_kinh_thien", 1, 162, "vo_dang_huyen_nhat_vo_tuong", "Huyền Nhất Vô Tượng"),
    (158, "vo_dang_kiem_phi_kinh_thien", 2, 1107, "vo_dang_kiem_minh_thuong_khung", "Kiếm Minh Thương Khung"),
    
    (164, "vo_dang_bac_cap_nhi_phuc", 1, 365, "vo_dang_thien_dia_vo_cuc", "Thiên Địa Vô Cực"),
    (164, "vo_dang_bac_cap_nhi_phuc", 2, 1078, "vo_dang_tao_hoa_thai_thanh", "Tạo Hóa Thái Thanh"),
    
    (165, "vo_dang_vo_nga_vo_kiem", 1, 365, "vo_dang_thien_dia_vo_cuc", "Thiên Địa Vô Cực"),
    (165, "vo_dang_vo_nga_vo_kiem", 2, 1078, "vo_dang_tao_hoa_thai_thanh", "Tạo Hóa Thái Thanh"),
    
    (267, "vo_dang_tam_hoan_thao_nguyet", 1, 368, "vo_dang_nhan_kiem_hop_nhat", "Nhân Kiếm Hợp Nhất"),
    (267, "vo_dang_tam_hoan_thao_nguyet", 2, 1079, "vo_dang_kiem_thuy_tinh_ha", "Kiếm Thùy Tinh Hà"),
    
    (365, "vo_dang_thien_dia_vo_cuc", 1, 1078, "vo_dang_tao_hoa_thai_thanh", "Tạo Hóa Thái Thanh"),
    (368, "vo_dang_nhan_kiem_hop_nhat", 1, 1079, "vo_dang_kiem_thuy_tinh_ha", "Kiếm Thùy Tinh Hà"),
]

for src_vid, src_tres_id, snum, tgt_vid, tgt_tres_id, tgt_name in synergy_table:
    sk = tres_skills.get(src_tres_id)
    if not sk:
        print(f"ERROR: {src_tres_id} not found in tres")
        continue
    # find synergy line in sk["lines"]
    syn_lines = [l for l in sk["lines"] if "liên kết" in l["label"] or l["target"]]
    if len(syn_lines) < snum:
        print(f"MISSING: {src_tres_id} has only {len(syn_lines)} synergy lines, expected at least {snum}")
    else:
        line = syn_lines[snum - 1]
        cur_target = line.get("target", "")
        match_ok = (cur_target == tgt_tres_id)
        print(f"[{'OK' if match_ok else 'THIẾU/LỖI':9s}] {sk['name']:25s} -> {tgt_name:25s} | Line Label: '{line['label']}' | Target in tres: '{cur_target}' (Cần: '{tgt_tres_id}') | Val: {line['v1']}% -> {line['vmax']}%")
