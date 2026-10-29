import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

with open("data/skill_fx/skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)
with open("data/skill_fx/missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)
with open("data/skill_fx/anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

mj_skills = [
    1737, 1749, 1738, 1750, 1740, 1751, 1757, 1765, 1739, 1753,
    1741, 1748, 1752, 1743, 1744, 1754, 1755, 1747, 1758, 1759, 1761, 1762
]

def check_anim(anim_key):
    if not anim_key:
        return "None"
    if anim_key in anims_fx:
        meta = anims_fx[anim_key]
        png_path = Path("assets/skill_fx") / f"{anim_key}.png"
        exists = png_path.exists()
        size_kb = png_path.stat().st_size // 1024 if exists else 0
        return f"OK (frames={meta.get('frames')}, dirs={meta.get('dirs')}, png={size_kb}KB)"
    return "MISSING in anims.json!"

print("================================================================================")
print("CHI TIẾT HIỆU ỨNG CHIÊU THỨC MINH GIÁO (CAST -> MISSILE -> HIT VFX)")
print("================================================================================")

for sid in mj_skills:
    s = skills_fx.get(str(sid))
    if not s:
        print(f"\n[ID {sid}] KHÔNG CÓ TRONG skills.json")
        continue

    sname = s.get("name", "")
    base = s.get("base", 0)
    char_anim = s.get("char_anim", 0)
    precast = s.get("precast", "")
    child = s.get("child", 0)
    form = s.get("form", 0)
    attack_radius = s.get("attack_radius", 0)
    vanish_skill = s.get("vanish_skill", 0)
    collide_skill = s.get("collide_skill", 0)
    is_phys = s.get("physical", 0)

    print(f"\n[Skill {sid}] {sname}")
    print(f"  • Loại: {'Ngoại công (Vật lý)' if is_phys else 'Nội công/Bùa'} | Động tác NV: {char_anim} | MissleForm: {form} | Cự ly đánh: {attack_radius}px")
    print(f"  • Ảnh xuất chiêu (Precast): {precast} -> {check_anim(precast)}")

    # Nếu base == 1: child là missile ID
    if base == 1 and child > 0:
        m = missiles_fx.get(str(child))
        if m:
            mname = m.get("name", "")
            anims = m.get("anims", [])
            # 4 phase: 0: wait, 1: fly, 2: collide, 3: vanish
            fly_anim = anims[1].get("anim") if len(anims) > 1 and anims[1] else None
            col_anim = anims[2].get("anim") if len(anims) > 2 and anims[2] else None
            van_anim = anims[3].get("anim") if len(anims) > 3 and anims[3] else None
            
            print(f"  • Đạn chính [Missile {child}] ({mname}):")
            print(f"      - Đạn bay (Fly): {fly_anim} -> {check_anim(fly_anim)}")
            print(f"      - Va chạm (Collide): {col_anim} -> {check_anim(col_anim)}")
            print(f"      - Trúng đích/Biến mất (Vanish/Hit): {van_anim} -> {check_anim(van_anim)}")
        else:
            print(f"  • Đạn chính [Missile {child}]: KHÔNG TÌM THẤY TRONG missiles.json!")
    elif base == 0 and child > 0:
        # child là skill con
        cs = skills_fx.get(str(child))
        if cs:
            print(f"  • Skill con [Skill {child}] ({cs.get('name','')}):")
            c_child = cs.get("child", 0)
            if cs.get("base") == 1 and c_child > 0:
                cm = missiles_fx.get(str(c_child))
                if cm:
                    c_anims = cm.get("anims", [])
                    c_fly = c_anims[1].get("anim") if len(c_anims) > 1 and c_anims[1] else None
                    c_hit = c_anims[3].get("anim") if len(c_anims) > 3 and c_anims[3] else None
                    print(f"      - Đạn con [Missile {c_child}] ({cm.get('name','')}): Fly={c_fly} -> {check_anim(c_fly)}, Hit={c_hit} -> {check_anim(c_hit)}")

    if vanish_skill > 0:
        vs = skills_fx.get(str(vanish_skill))
        if vs:
            print(f"  • Kỹ năng nổ khi biến mất [Vanish Skill {vanish_skill}] ({vs.get('name','')}):")
            v_child = vs.get("child", 0)
            if vs.get("base") == 1 and v_child > 0:
                vm = missiles_fx.get(str(v_child))
                if vm:
                    v_anims = vm.get("anims", [])
                    v_fly = v_anims[1].get("anim") if len(v_anims) > 1 and v_anims[1] else None
                    v_hit = v_anims[3].get("anim") if len(v_anims) > 3 and v_anims[3] else None
                    print(f"      - Đạn nổ [Missile {v_child}] ({vm.get('name','')}): Fly={v_fly} -> {check_anim(v_fly)}, Hit={v_hit} -> {check_anim(v_hit)}")
