"""Sinh dữ liệu 200 đợt chơi cho Ải "Bảo Vệ Trụ Danh Dự":
- 200 đợt, mỗi đợt 20 quái, cấp độ từ 1 đến 200
- Mỗi 10 đợt có 1 Boss (tổng 20 Boss), máu boss x15
- Mỗi 10 đợt đổi 1 Hệ Ngũ Hành: Kim -> Mộc -> Thủy -> Hỏa -> Thổ -> Kim ...
- Quái lấy từ động vật sơ cấp (heo, hươu, nhím, lợn, sói...) đến các cao thủ giang hồ, sơn tặc, boss VLTK
- Mỗi đợt có 1 skill buff của các phái (chạy nhanh, hồi máu, kháng, né tránh, vô hình độc, choáng, mana shield...)
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

SECT_BUFFS = [
    # Kim: Thiếu Lâm, Thiên Vương
    {"sect": "Thiếu Lâm", "name": "Kim Cang Hộ Thể", "desc": "Tăng 50% toàn bộ kháng tính và phòng ngự", "type": "resist", "value": 50},
    {"sect": "Thiếu Lâm", "name": "Bất Động Minh Vương", "desc": "Miễn dịch mọi trạng thái khống chế (choáng, chậm)", "type": "immune_cc", "value": 1},
    {"sect": "Thiếu Lâm", "name": "La Hán Trận", "desc": "Phản đòn 35% sát thương cận chiến", "type": "reflect", "value": 35},
    {"sect": "Thiếu Lâm", "name": "Hỗn Nguyên Nhất Khí Công", "desc": "Tăng 30% sinh lực tối đa", "type": "max_hp", "value": 30},
    {"sect": "Thiên Vương", "name": "Kim Chung Tráo", "desc": "Giảm 40% sát thương phải chịu", "type": "dmg_reduce", "value": 40},
    {"sect": "Thiên Vương", "name": "Đoạn Hồn Thích", "desc": "Tăng 60% tốc độ di chuyển xông thẳng vào trụ", "type": "speed", "value": 60},
    {"sect": "Thiên Vương", "name": "Tĩnh Tâm Quyết", "desc": "Hồi phục 3% máu tối đa mỗi giây", "type": "regen_hp", "value": 3},
    {"sect": "Thiên Vương", "name": "Bất Khuất Thần Công", "desc": "Khi dưới 30% máu nhận khiên hộ thể bất tử 3 giây", "type": "shield_low_hp", "value": 3},

    # Mộc: Đường Môn, Ngũ Độc
    {"sect": "Đường Môn", "name": "Mê Ảnh Tung", "desc": "Tăng 50% tốc độ chạy và 40% tỉ lệ né tránh", "type": "speed_dodge", "value": 50},
    {"sect": "Đường Môn", "name": "Vô Ảnh Tiêu", "desc": "Tăng 25% tốc độ tấn công đánh trụ", "type": "atk_speed", "value": 25},
    {"sect": "Đường Môn", "name": "Tâm Nhãn", "desc": "Tăng 100% độ chính xác, không thể bị né tránh", "type": "accuracy", "value": 100},
    {"sect": "Đường Môn", "name": "Bẫy Độn Giáp Hộ Thể", "desc": "Kháng độc 80% và giảm sát thương bẫy", "type": "resist_poison", "value": 80},
    {"sect": "Ngũ Độc", "name": "Vô Hình Độc", "desc": "Tỏa ra khí độc rút 2% máu mỗi giây cho kẻ địch quanh quái", "type": "aura_poison", "value": 2},
    {"sect": "Ngũ Độc", "name": "Bách Độc Xuyên Tâm", "desc": "Đòn đánh làm giảm 30% phòng ngự của mục tiêu", "type": "armor_shred", "value": 30},
    {"sect": "Ngũ Độc", "name": "Vạn Cổ Khô Vinh", "desc": "Kháng toàn bộ độc tính và hiệu ứng suy yếu", "type": "immune_poison", "value": 1},
    {"sect": "Ngũ Độc", "name": "Chu Cáp Thanh Phổ", "desc": "Tăng 40% kháng Lôi và kháng Thủy", "type": "resist_dual", "value": 40},

    # Thủy: Nga Mi, Thúy Yên
    {"sect": "Nga Mi", "name": "Từ Hàng Phổ Độ", "desc": "Hào quang hồi 4% máu mỗi 2 giây cho toàn bộ quái cùng đợt", "type": "heal_aura", "value": 4},
    {"sect": "Nga Mi", "name": "Mộng Điệp", "desc": "Hồi phục liên tục nội lực và miễn dịch hút mana", "type": "regen_mana", "value": 10},
    {"sect": "Nga Mi", "name": "Lưu Thủy", "desc": "Tăng 45% tốc độ di chuyển uyển chuyển", "type": "speed", "value": 45},
    {"sect": "Nga Mi", "name": "Phật Tâm Từ Hữu", "desc": "Tăng 25% sinh lực và 25% kháng tất cả", "type": "all_res_hp", "value": 25},
    {"sect": "Thúy Yên", "name": "Hộ Thể Hàn Băng", "desc": "Đóng băng người tấn công trong 1.5 giây nếu chạm vào", "type": "freeze_attacker", "value": 1.5},
    {"sect": "Thúy Yên", "name": "Phù Vân Lược Ảnh", "desc": "Tăng 55% tốc độ di chuyển và tàng hình trong 3 giây đầu", "type": "speed_stealth", "value": 55},
    {"sect": "Thúy Yên", "name": "Băng Tâm Tiên Tử", "desc": "Giảm 50% thời gian chịu hiệu ứng khống chế", "type": "cc_reduction", "value": 50},
    {"sect": "Thúy Yên", "name": "Băng Cốt Tuyết Cơ", "desc": "Tăng 60% kháng Băng và hấp thụ sát thương Băng", "type": "resist_cold", "value": 60},

    # Hỏa: Cái Bang, Thiên Nhẫn
    {"sect": "Cái Bang", "name": "Tiêu Dao Du", "desc": "Tăng 60% tốc độ di chuyển và 50% tỉ lệ né tránh đòn", "type": "speed_dodge", "value": 60},
    {"sect": "Cái Bang", "name": "Hoạt Bất Lưu Thủ", "desc": "Né tránh đòn tấn công vật lý tăng vọt 65%", "type": "dodge", "value": 65},
    {"sect": "Cái Bang", "name": "Túy Điệp Cuồng Vũ", "desc": "Kháng chí mạng và tăng 35% sát thương lên trụ", "type": "crit_res", "value": 35},
    {"sect": "Cái Bang", "name": "Hóa Hiểm Vi Di", "desc": "Khi bị khống chế tự giải phóng và tăng tốc chạy", "type": "cleanse_speed", "value": 1},
    {"sect": "Thiên Nhẫn", "name": "Ma Diễm Thao Thiên", "desc": "Quái bốc cháy, kẻ địch đứng gần bị thiêu đốt 3% máu/s", "type": "burn_aura", "value": 3},
    {"sect": "Thiên Nhẫn", "name": "Đạp Tuyết Vô Ngân", "desc": "Tăng 50% tốc độ chạy và kháng làm chậm 100%", "type": "immune_slow", "value": 50},
    {"sect": "Thiên Nhẫn", "name": "Bi Tô Thanh Phong", "desc": "Hào quang làm giảm 25% kháng tính của người chơi", "type": "debuff_res", "value": 25},
    {"sect": "Thiên Nhẫn", "name": "Hấp Tinh Trận", "desc": "Đòn đánh hút 10% sát thương gây ra thành máu cho quái", "type": "lifesteal", "value": 10},

    # Thổ: Võ Đang, Côn Lôn
    {"sect": "Võ Đang", "name": "Thọa Khí Quyết", "desc": "Tăng 45% tốc độ chạy và tăng tốc hồi phục", "type": "speed_regen", "value": 45},
    {"sect": "Võ Đang", "name": "Bác Cấp Nhi Phục", "desc": "Khiên Chân Khí chặn 40% sát thương nhận vào", "type": "mana_shield", "value": 40},
    {"sect": "Võ Đang", "name": "Thái Cực Thần Công", "desc": "Tăng 40% phòng ngự nội công và kháng Lôi", "type": "resist_light", "value": 40},
    {"sect": "Võ Đang", "name": "Thê Vân Tung", "desc": "Tăng 50% tốc độ di chuyển lướt gió", "type": "speed", "value": 50},
    {"sect": "Côn Lôn", "name": "Sương Ngạo Côn Lôn", "desc": "Tăng 50% tốc độ chạy và 45% né đòn", "type": "speed_dodge", "value": 50},
    {"sect": "Côn Lôn", "name": "Thiên Thanh Địa Trọc", "desc": "Khi chết quái phát nổ làm choáng xung quanh 1 giây", "type": "death_stun", "value": 1},
    {"sect": "Côn Lôn", "name": "Thanh Phong Phù", "desc": "Tăng 50% tốc độ đánh và giảm thời gian trúng bùa", "type": "cleanse_buff", "value": 50},
    {"sect": "Côn Lôn", "name": "Khí Diệt Thần Trọng", "desc": "Hào quang rút mana của mục tiêu khi đánh cận chiến", "type": "mana_burn", "value": 15},

    # Môn phái bổ sung: Hoa Sơn, Đoàn Thị, Minh Giáo
    {"sect": "Hoa Sơn", "name": "Tử Hà Thần Công", "desc": "Tăng 30% kháng tất cả và giảm 25% sát thương nhận", "type": "resist_all", "value": 30},
    {"sect": "Hoa Sơn", "name": "Bạch Lộc Di Thân", "desc": "Lướt nhanh tăng 55% tốc chạy", "type": "speed", "value": 55},
    {"sect": "Minh Giáo", "name": "Càn Khôn Đại Na Di", "desc": "Chuyển hóa 30% sát thương gánh chịu thành hồi máu", "type": "absorb_heal", "value": 30},
    {"sect": "Minh Giáo", "name": "Thánh Hỏa Lệnh Pháp", "desc": "Tăng 40% tốc đánh và tốc chạy", "type": "haste", "value": 40},
    {"sect": "Đoàn Thị", "name": "Lăng Ba Vi Bộ", "desc": "Tăng 70% tốc độ di chuyển và miễn dịch làm chậm", "type": "super_speed", "value": 70},
    {"sect": "Đoàn Thị", "name": "Khô Vinh Thiền Công", "desc": "Chuyển hóa luân phiên giữa kháng vật lý và kháng phép", "type": "hybrid_res", "value": 40},
]

def load_monsters():
    with open('data/monsters/monsters.json', encoding='utf-8') as f:
        monsters = json.load(f)
    
    # Lọc quái thú thường (level thấp)
    low_animals = [
        (11, "Heo rừng"), (43, "Heo trắng"), (42, "Hươu đốm"), (12, "Nhím"),
        (31, "Kim Miêu"), (34, "Linh Miêu"), (33, "Hoán hùng"), (36, "Khỉ xám"),
        (5, "Sói xám"), (6, "Sói đỏ"), (7, "Sói xanh"), (8, "Sói tuyết"),
        (0, "Đông Bắc hổ"), (1, "Hoa Nam hổ"), (2, "Bạch Hổ"), (3, "Kim Tiền báo"),
        (4, "Báo trắng"), (15, "Gấu nâu"), (16, "Gấu đen"), (21, "Rắn xanh")
    ]
    
    # Lấy thêm quái giang hồ bình thường từ monsters.json
    regular_monsters = []
    boss_monsters = []
    
    for mid_str, m in monsters.items():
        mid = int(mid_str)
        name = m.get('name', '').strip()
        if not name or 'chưa dùng' in name.lower() or name.startswith('test') or 'rương' in name.lower():
            continue
        is_boss = m.get('is_boss', False) or 'boss' in name.lower() or 'thống lĩnh' in name.lower() or 'trại chủ' in name.lower()
        if is_boss:
            boss_monsters.append((mid, name, m.get('series', 0)))
        else:
            if (mid, name) not in low_animals:
                regular_monsters.append((mid, name, m.get('series', 0)))
                
    return low_animals, regular_monsters, boss_monsters

def generate_200_waves():
    low_animals, regular_monsters, boss_monsters = load_monsters()
    
    # 5 Hệ ngũ hành: 0: Kim, 1: Mộc, 2: Thủy, 3: Hỏa, 4: Thổ
    ELEMENTS = [0, 1, 2, 3, 4]
    ELEMENT_NAMES = ["Kim", "Mộc", "Thủy", "Hỏa", "Thổ"]
    
    waves = []
    total_buffs = len(SECT_BUFFS)
    
    # 20 Boss danh tiếng cho 20 đợt boss (đợt 10, 20, 30... 200)
    selected_bosses = [
        (1006, "Thủ Lĩnh Dã Thú"),
        (1011, "Thủy Quỷ Vương"),
        (1020, "Hắc Phong Trại Chủ"),
        (1030, "Lâm Tặc Đầu Mục"),
        (1040, "Đại Đao Phỉ Thủ"),
        (1050, "Cổ Mộ U Hồn Tướng"),
        (1060, "Khoái Đao Thích Khách"),
        (1070, "Ngũ Độc Giáo Đầu"),
        (1080, "Thiên Nhẫn Sát Thủ"),
        (1090, "Vạn Độc Xà Vương"),
        (1100, "Tây Vực Ma Đầu"),
        (1110, "Kim Quốc Tiên Phong Tướng"),
        (1120, "Tống Triều Đô Thống"),
        (1130, "Đột Quyết Dũng Sĩ"),
        (1140, "Thiên Hộ Trưởng"),
        (1150, "Đại Kim Bát Kỳ Tướng"),
        (1160, "Long Trụ Thủ Hộ Giả"),
        (1170, "Cực Bắc Huyết Ma"),
        (1180, "Lâm An Phản Tướng"),
        (1190, "Chiến Thần Lâm An")
    ]
    
    animal_idx = 0
    reg_idx = 0
    
    for w in range(1, 201):
        level = w
        is_boss_wave = (w % 10 == 0)
        boss_idx = (w // 10) - 1
        
        # Hệ đổi sau mỗi 10 đợt (sau mỗi đợt boss)
        element_idx = ((w - 1) // 10) % len(ELEMENTS)
        element = ELEMENTS[element_idx]
        element_name = ELEMENT_NAMES[element_idx]
        
        # Skill buff xoay vòng liên tục để sử dụng hết 46+ skill buff
        buff = SECT_BUFFS[(w - 1) % total_buffs]
        
        # Chọn quái:
        # Đợt 1-40: lấy thú hoang (heo, hươu, nhím, lợn...)
        # Đợt 41-200: lấy lần lượt các quái giang hồ trong data
        if w <= 40:
            m_tuple = low_animals[animal_idx % len(low_animals)]
            animal_idx += 1
            monster_id = m_tuple[0]
            monster_name = m_tuple[1]
        else:
            m_tuple = regular_monsters[reg_idx % len(regular_monsters)]
            reg_idx += 1
            monster_id = m_tuple[0]
            monster_name = m_tuple[1]
            
        wave_data = {
            "wave": w,
            "level": level,
            "element": element,
            "element_name": element_name,
            "monster_count": 20,
            "monster_id": monster_id,
            "monster_name": monster_name,
            "is_boss_wave": is_boss_wave,
            "buff": {
                "sect": buff["sect"],
                "name": buff["name"],
                "desc": buff["desc"],
                "type": buff["type"],
                "value": buff["value"]
            }
        }
        
        if is_boss_wave:
            b = selected_bosses[boss_idx % len(selected_bosses)]
            wave_data["boss"] = {
                "monster_id": b[0],
                "name": b[1],
                "hp_multiplier": 15.0, # máu x15
                "scale": 1.4
            }
            
        waves.append(wave_data)
        
    out_path = "data/battle/honor_defense_waves.json"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fp:
        json.dump({"total_waves": 200, "waves": waves}, fp, ensure_ascii=False, indent=2)
        
    print(f"Generated {len(waves)} waves successfully at {out_path}!")

if __name__ == "__main__":
    generate_200_waves()
