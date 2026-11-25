"""Định nghĩa các bộ trang bị Hoàng Kim Môn Phái cấp 10/Anh Hào cho 4 môn phái mới:
- Dương Môn (menpai = 13, Hệ Kim): Nhánh Cung (Group 674) và Nhánh Thương (Group 675)
- Vũ Hồn (menpai = 11, Hệ Hỏa): Nhánh Đao Pháp (Group 676) và Nhánh Thuẫn Pháp (Group 677)
- Tiêu Dao (menpai = 12, Hệ Thổ): Nhánh Kiếm Pháp (Group 678) và Nhánh Cầm/Âm Luật (Group 679)
- Minh Giáo (menpai = 14, Hệ Mộc): Nhánh Đao Pháp (Group 680) và Nhánh Chùy/Kích (Group 681)
"""

## Hình NGOÀI MAP (mã hình nhân vật ghép bộ phận, data/avatar/*.json) cho mũ/áo hoàng kim tự dựng — bộ tự dựng không có
## hàng trong GoldEquipRes gốc nên dùng trang phục riêng của phái trong client 15 phái: menpai -> (áo, mũ).
## 81/55 = bộ 161 (Vũ Hồn), 82/56 = bộ 141/144 (Tiêu Dao), 83/57 = bộ 120 (Dương Môn). Đọc ở Equipment.get_appearance.
## Vũ khí không cần: Đao thuẫn/Thuẫn đao/Cầm/Cung đã ra đúng hình 161/162/163/164 theo loại.
SECT_AVATAR_RES = {11: (81, 55), 12: (82, 56), 13: (83, 57)}
DETAIL_ARMOR, DETAIL_HELM = 2, 7


def make_item(name, detail, particular, level, series, price, image, intro, base, require, menpai, magic, group, set_id, ext, row):
    item = _make_item(name, detail, particular, level, series, price, image, intro, base, require, menpai, magic, group,
                      set_id, ext, row)
    res = SECT_AVATAR_RES.get(menpai)
    if res and detail in (DETAIL_ARMOR, DETAIL_HELM):
        item["avatar_res"] = res[0] if detail == DETAIL_ARMOR else res[1]
    return item


def _make_item(name, detail, particular, level, series, price, image, intro, base, require, menpai, magic, group, set_id, ext, row):
    return {
        "name": name,
        "detail": detail,
        "particular": particular,
        "level": level,
        "series": series,
        "price": price,
        "image": image,
        "intro": intro,
        "base": base,
        "require": require,
        "menpai": menpai,
        "magic": magic,
        "group": group,
        "need1": 4,
        "need2": 7,
        "set_id": set_id,
        "ext": ext,
        "row": row
    }

# -----------------------------------------------------------------------------
# 1. DƯƠNG MÔN THƯƠNG PHÁP (Hệ Kim, series = 0, menpai = 13, Group 675, Ext 725)
# -----------------------------------------------------------------------------
def build_duong_gia_spear_set(start_row: int) -> list[dict]:
    menpai = 13
    req = [["requirelevel", 120], ["requiremenpai", menpai]]
    group, ext = 675, 725
    items = []

    # 1. Dây chuyền
    items.append(make_item(
        "Anh Hào Phá Quân Hạng Liên", 4, 1, 10, 4, 99999,
        r"\spr\item\equip\nick\obj-neck109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (1)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_physicsres_yan_p", "name": "Bỏ qua kháng vật lý", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Tỷ lệ chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row
    ))

    # 2. Mũ
    items.append(make_item(
        "Anh Hào Phá Quân Khôi", 7, 4, 10, 0, 99999,
        r"\spr\item\equip\cap\obj-ma-cap120.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (2)",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "manareplenish_v", "name": "Hồi phục nội lực", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row + 1
    ))

    # 3. Nhẫn trên
    items.append(make_item(
        "Anh Hào Phá Quân Thượng Giới", 3, 0, 10, 4, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (3)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Bao tay
    items.append(make_item(
        "Anh Hào Phá Quân Hộ Oản", 8, 1, 10, 0, 99999,
        r"\spr\item\equip\bangle\obj-bangle109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (4)",
        [["armordefense_v", 135, 135], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[20, 30], [-1, -1], [0, 0]]},
            {"attrib": "fireres_yan_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_physicsres_yan_p", "name": "Bỏ qua kháng vật lý", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Thắt lưng
    items.append(make_item(
        "Anh Hào Phá Quân Yêu Đới", 6, 0, 10, 4, 99999,
        r"\spr\item\equip\sash\obj-sash109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (5)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Áo giáp
    items.append(make_item(
        "Anh Hào Phá Quân Giáp Y", 2, 4, 10, 0, 99999,
        r"\spr\item\equip\armor\obj-ma-cloth120.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (6)",
        [["armordefense_v", 720, 720], ["durability_v", 90, 90]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "fireres_yan_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[600, 800], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Vũ khí Thương
    items.append(make_item(
        "Anh Hào Phá Quân Kích", 0, 3, 10, 0, 99999,
        r"\spr\item\equip\closeweapon\obj-spear12.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (7)",
        [
            ["weapondamagemin_v", 52, 52],
            ["weapondamagemax_v", 98, 98],
            ["attackratingenhance_p", 35, 35],
            ["durability_v", 99, 99]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[30, 30], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[105, 110], [-1, -1], [0, 0]]},
            {"attrib": "addphysicsdamage_v", "name": "Tăng sát thương Vật lý", "range": [[190, 210], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "addphysicsdamage_p", "name": "Tăng sát thương vật lý %", "range": [[90, 105], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Tỷ lệ chí mạng", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Giày
    items.append(make_item(
        "Anh Hào Phá Quân Ngoa", 5, 0, 10, 0, 99999,
        r"\spr\item\equip\boots\obj-shoes120.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (8)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Ngọc bội
    items.append(make_item(
        "Anh Hào Phá Quân Yêu Trụy", 9, 1, 10, 4, 99999,
        r"\spr\item\equip\waist\obj-waist109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (9)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "anti_physicsres_yan_p", "name": "Bỏ qua kháng vật lý", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Nhẫn dưới
    items.append(make_item(
        "Anh Hào Phá Quân Hạ Giới", 3, 0, 10, 4, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Dương Môn Thương Pháp cấp Anh Hào (10)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


# -----------------------------------------------------------------------------
# 2. VŨ HỒN ĐAO PHÁP (Hệ Hỏa, series = 3, menpai = 11, Group 676, Ext 726)
# -----------------------------------------------------------------------------
def build_vu_hon_blade_set(start_row: int) -> list[dict]:
    menpai = 11
    req = [["requirelevel", 120], ["requiremenpai", menpai]]
    group, ext = 676, 726
    items = []

    # 1. Dây chuyền (Hệ Mộc kích hoạt Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Hạng Liên", 4, 1, 10, 1, 99999,
        r"\spr\item\equip\nick\obj-neck109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (1)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_coldres_yan_p", "name": "Bỏ qua kháng băng", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row
    ))

    # 2. Mũ (Hệ Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Khôi", 7, 4, 10, 3, 99999,
        r"\spr\item\equip\cap\obj-ma-cap120.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (2)",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "fireres_yan_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "manareplenish_v", "name": "Hồi phục nội lực", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "freezetimereduce_p", "name": "Giảm thời gian làm chậm", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row + 1
    ))

    # 3. Nhẫn trên (Hệ Mộc)
    items.append(make_item(
        "Vũ Mục Trảm Ma Thượng Giới", 3, 0, 10, 1, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (3)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Bao tay (Hệ Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Hộ Oản", 8, 1, 10, 3, 99999,
        r"\spr\item\equip\bangle\obj-bangle109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (4)",
        [["armordefense_v", 135, 135], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[20, 30], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_coldres_yan_p", "name": "Bỏ qua kháng băng", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Thắt lưng (Hệ Mộc)
    items.append(make_item(
        "Vũ Mục Trảm Ma Yêu Đới", 6, 0, 10, 1, 99999,
        r"\spr\item\equip\sash\obj-sash109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (5)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "freezetimereduce_p", "name": "Giảm thời gian làm chậm", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Áo giáp (Hệ Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Chiến Giáp", 2, 4, 10, 3, 99999,
        r"\spr\item\equip\armor\obj-ma-cloth120.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (6)",
        [["armordefense_v", 720, 720], ["durability_v", 90, 90]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[600, 800], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Vũ khí Đao Thuẫn (Particular 7, Hệ Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Đao", 0, 7, 10, 3, 99999,
        r"\spr\item\equip\closeweapon\obj-shield01.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (7)",
        [
            ["weapondamagemin_v", 50, 50],
            ["weapondamagemax_v", 95, 95],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 99, 99]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[30, 30], [-1, -1], [0, 0]]},
            {"attrib": "addfiredamage_v", "name": "Hỏa sát nội công", "range": [[180, 220], [-1, -1], [0, 0]]},
            {"attrib": "addphysicsdamage_v", "name": "Tăng sát thương Vật lý", "range": [[180, 200], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "addphysicsdamage_p", "name": "Tăng sát thương vật lý %", "range": [[85, 100], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[12, 18], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Giày (Hệ Hỏa)
    items.append(make_item(
        "Vũ Mục Trảm Ma Ngoa", 5, 0, 10, 3, 99999,
        r"\spr\item\equip\boots\obj-shoes120.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (8)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "freezetimereduce_p", "name": "Giảm thời gian làm chậm", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Ngọc bội (Hệ Mộc)
    items.append(make_item(
        "Vũ Mục Trảm Ma Yêu Trụy", 9, 1, 10, 1, 99999,
        r"\spr\item\equip\waist\obj-waist109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (9)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "coldres_yan_p", "name": "Kháng băng", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "anti_coldres_yan_p", "name": "Bỏ qua kháng băng", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Nhẫn dưới (Hệ Mộc)
    items.append(make_item(
        "Vũ Mục Trảm Ma Hạ Giới", 3, 0, 10, 1, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Vũ Hồn Đao Pháp Hoàng Kim (10)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


# -----------------------------------------------------------------------------
# 3. VŨ HỒN THUẪN PHÁP cấp Anh Hào - Anh Hào Bá Khí (theo ảnh game, menpai = 11, Group 677, Ext 727)
# -----------------------------------------------------------------------------
def build_vu_hon_shield_set(start_row: int) -> list[dict]:
    """Bộ Vũ Hồn Thuẫn Pháp cấp Anh Hào — "Anh Hào Bá Khí" (cấp 120, Group 677). Tên, hệ, chỉ số lấy đúng theo ảnh
    chụp game (bộ hoàng kim 4 phái mới không có trong nguồn 15 phái). Mỗi món: 6 dòng thường (dòng chẵn luôn hiệu lực,
    dòng lẻ là dòng ẩn bật theo ngũ hành) + 2 dòng mở rộng bật theo số món cùng bộ (None = không có dòng)."""
    menpai = 11
    req = [["requirelevel", 120], ["requiremenpai", menpai]]
    group, ext = 677, 727
    intro = "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Anh Hào (%d)"
    RANDOM_SPREAD = 0.05
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4

    def line(attrib, name, value):
        return {"attrib": attrib, "name": name, "range": [[value, value], [-1, -1], [0, 0]]}

    def skill(level):
        ## allskill_v mã skill 0 = "Võ công vốn có" (mọi kỹ năng môn phái).
        return line("allskill_v", "Kỹ năng Võ công vốn có", level)

    def item(name, detail, particular, series, image, base, magic, set_id):
        ## 6 dòng thường roll NGẪU NHIÊN ±5% quanh số trong ảnh (đồ rơi dùng ItemGenerator.generate_gold_random).
        ## Giữ cố định: số cấp kỹ năng (allskill_v), 2 dòng bộ (mở rộng) và chỉ số gốc (sát thương, né tránh, độ bền).
        for ln in magic[:6]:
            if ln and ln["attrib"] != "allskill_v":
                v = ln["range"][0][0]
                ln["range"][0] = [round(v * (1 - RANDOM_SPREAD)), round(v * (1 + RANDOM_SPREAD))]
        return make_item(name, detail, particular, 10, series, 99999, image, intro % set_id, base, req, menpai,
                         magic, group, set_id, ext, start_row + set_id - 1)

    return [
        item("Anh Hào Bá Khí Hạng Liên", 4, 1, MOC, r"\spr\item\equip\nick\obj-neck109.spr", [], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2199),
            line("coldres_yan_p", "Kháng băng", 105),
            line("manamax_yan_v", "Nội lực tối đa", 1744),
            line("poisontimereduce_p", "Thời gian trúng độc", 124),
            line("allres_yan_p", "Kháng tất cả", 49),
            line("block_rate", "Xác suất hóa giải sát thương", 9),
            skill(3),
            line("enhancehit_rate", "Xác suất trọng kích", 7),
        ], 1),
        item("Anh Hào Bá Khí Quán", 7, 4, HOA, r"\spr\item\equip\cap\obj-ma-cap120.spr",
             [["armordefense_v", 360, 360], ["durability_v", 85, 85]], [
            line("lifemax_yan_p", "Sinh lực tối đa", 181),
            line("poisonres_yan_p", "Kháng độc", 106),
            line("manamax_yan_v", "Nội lực tối đa", 1758),
            line("sorbdamage_yan_p", "Triệt tiêu sát thương", 108),
            line("skill_enhance", "Tăng công kích kỹ năng", 134),
            line("anti_sorbdamage_yan_p", "Gia tăng sát thương", 86),
            line("anti_block_rate", "Tỷ lệ hóa giải cách đáng", 10),
            line("enhancehit_rate", "Xác suất trọng kích", 8),
        ], 2),
        item("Anh Hào Bá Khí Ngự Quân Chỉ Hoàn", 3, 0, THO, r"\spr\item\equip\ring\obj-ring109.spr", [], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2399),
            line("fireres_yan_p", "Kháng hỏa", 107),
            line("manamax_yan_v", "Nội lực tối đa", 1789),
            line("stuntimereduce_p", "Thời gian choáng", 118),
            line("skill_enhance", "Tăng công kích kỹ năng", 135),
            line("anti_block_rate", "Tỷ lệ hóa giải cách đáng", 9),
            skill(1),
        ], 3),
        item("Anh Hào Bá Khí Thúc Uyển", 8, 1, KIM, r"\spr\item\equip\bangle\obj-bangle109.spr",
             [["armordefense_v", 135, 135], ["durability_v", 80, 80]], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2476),
            line("lightingres_yan_p", "Kháng lôi", 106),
            line("manamax_yan_v", "Nội lực tối đa", 1720),
            line("sorbdamage_yan_p", "Triệt tiêu sát thương", 113),
            line("skill_enhance", "Tăng công kích kỹ năng", 130),
            line("block_rate", "Xác suất hóa giải sát thương", 10),
            skill(3),
            line("enhancehit_rate", "Xác suất trọng kích", 8),
        ], 4),
        item("Anh Hào Bá Khí Yêu Đới", 6, 0, THUY, r"\spr\item\equip\sash\obj-sash109.spr",
             [["armordefense_v", 160, 160], ["durability_v", 80, 80]], [
            line("lifemax_yan_p", "Sinh lực tối đa", 175),
            line("physicsres_yan_p", "Phòng thủ vật lý", 105),
            line("manamax_yan_v", "Nội lực tối đa", 1856),
            line("freezetimereduce_p", "Thời gian làm chậm", 124),
            line("skill_enhance", "Tăng công kích kỹ năng", 133),
            line("block_rate", "Xác suất hóa giải sát thương", 9),
            line("lifereplenish_p", "Hồi phục sinh lực", 13),
            skill(3),
        ], 5),
        item("Anh Hào Bá Khí Giáp Y", 2, 4, MOC, r"\spr\item\equip\armor\obj-ma-cloth120.spr",
             [["armordefense_v", 720, 720], ["durability_v", 90, 90]], [
            line("lifemax_yan_p", "Sinh lực tối đa", 179),
            line("coldres_yan_p", "Kháng băng", 108),
            line("manamax_yan_v", "Nội lực tối đa", 1742),
            line("poisontimereduce_p", "Thời gian trúng độc", 121),
            line("fasthitrecover_yan_v", "Thời gian phục hồi", 84),
            line("anti_sorbdamage_yan_p", "Gia tăng sát thương", 80),
            line("lifereplenish_p", "Hồi phục sinh lực", 13),
            skill(1),
        ], 6),
        ## Vũ khí Thuẫn đao (Particular 8). Hình obj-shield03 = khiên nâu + đao vàng tua xanh, đúng hình trong ảnh.
        item("Anh Hào Bá Khí Thuẫn", 0, 8, HOA, r"\spr\item\equip\closeweapon\obj-shield03.spr", [
            ["weapondamagemin_v", 69, 69],
            ["weapondamagemax_v", 128, 128],
            ["attackratingenhance_p", -30, -30],
            ["durability_v", 99, 99],
        ], [
            line("attackspeed_yan_v", "Tốc độ đánh - ngoại công", 205),
            line("poisonres_yan_p", "Kháng độc", 107),
            line("addphysicsdamage_v", "Sát thương vật lý - ngoại công", 189),
            line("sorbdamage_yan_p", "Triệt tiêu sát thương", 108),
            line("skill_enhance", "Tăng công kích kỹ năng", 133),
            line("anti_sorbdamage_yan_p", "Gia tăng sát thương", 81),
            line("lifereplenish_p", "Hồi phục sinh lực", 13),
            skill(1),
        ], 7),
        item("Anh Hào Bá Khí Ngoa", 5, 0, THO, r"\spr\item\equip\boots\obj-shoes120.spr",
             [["armordefense_v", 160, 160], ["durability_v", 80, 80]], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2507),
            line("fireres_yan_p", "Kháng hỏa", 106),
            line("manamax_yan_v", "Nội lực tối đa", 1733),
            line("stuntimereduce_p", "Thời gian choáng", 120),
            line("fastwalkrun_p", "Tốc độ di chuyển", 117),
            line("block_rate", "Xác suất hóa giải sát thương", 10),
            line("lifereplenish_p", "Hồi phục sinh lực", 13),
            line("enhancehit_rate", "Xác suất trọng kích", 8),
        ], 8),
        item("Anh Hào Bá Khí Yêu Trụy", 9, 1, KIM, r"\spr\item\equip\waist\obj-waist109.spr", [], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2296),
            line("lightingres_yan_p", "Kháng lôi", 109),
            line("manamax_yan_v", "Nội lực tối đa", 1825),
            line("sorbdamage_yan_p", "Triệt tiêu sát thương", 108),
            line("skill_enhance", "Tăng công kích kỹ năng", 131),
            line("block_rate", "Xác suất hóa giải sát thương", 9),
            skill(3),
            line("anti_block_rate", "Tỷ lệ hóa giải cách đáng", 9),
        ], 9),
        item("Anh Hào Bá Khí Trấn Sơn Chỉ Hoàn", 3, 0, THUY, r"\spr\item\equip\ring\obj-ring109.spr", [], [
            line("lifemax_yan_v", "Sinh lực tối đa", 2240),
            line("physicsres_yan_p", "Phòng thủ vật lý", 108),
            line("manamax_yan_v", "Nội lực tối đa", 1758),
            line("freezetimereduce_p", "Thời gian làm chậm", 119),
            line("skill_enhance", "Tăng công kích kỹ năng", 132),
            line("anti_block_rate", "Tỷ lệ hóa giải cách đáng", 10),
            skill(1),
        ], 10),
    ]


# -----------------------------------------------------------------------------
# 4. TIÊU DAO KIẾM PHÁP (Hệ Thổ, series = 4, menpai = 12, Group 678, Ext 728)
# -----------------------------------------------------------------------------
def build_tieu_dao_sword_set(start_row: int) -> list[dict]:
    menpai = 12
    req = [["requirelevel", 120], ["requiremenpai", menpai]]
    group, ext = 678, 728
    items = []

    # 1. Dây chuyền (Hệ Hỏa kích hoạt Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Hạng Liên", 4, 1, 10, 3, 99999,
        r"\spr\item\equip\nick\obj-neck109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (1)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row
    ))

    # 2. Mũ (Hệ Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Quán", 7, 4, 10, 4, 99999,
        r"\spr\item\equip\cap\obj-ma-cap120.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (2)",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "manareplenish_v", "name": "Hồi phục nội lực", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row + 1
    ))

    # 3. Nhẫn trên (Hệ Hỏa)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Thượng Giới", 3, 0, 10, 3, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (3)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Bao tay (Hệ Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Hộ Oản", 8, 1, 10, 4, 99999,
        r"\spr\item\equip\bangle\obj-bangle109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (4)",
        [["armordefense_v", 135, 135], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[20, 30], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Thắt lưng (Hệ Hỏa)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Yêu Đới", 6, 0, 10, 3, 99999,
        r"\spr\item\equip\sash\obj-sash109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (5)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Áo giáp (Hệ Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Đạo Bào", 2, 4, 10, 4, 99999,
        r"\spr\item\equip\armor\obj-ma-cloth120.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (6)",
        [["armordefense_v", 720, 720], ["durability_v", 90, 90]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[600, 800], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Vũ khí Kiếm (Particular 0, Hệ Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Kiếm", 0, 0, 10, 4, 99999,
        r"\spr\item\equip\closeweapon\obj-sword12.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (7)",
        [
            ["weapondamagemin_v", 48, 48],
            ["weapondamagemax_v", 92, 92],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 99, 99]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[30, 30], [-1, -1], [0, 0]]},
            {"attrib": "addlightingdamage_v", "name": "Lôi sát", "range": [[180, 220], [-1, -1], [0, 0]]},
            {"attrib": "addphysicsdamage_v", "name": "Tăng sát thương Vật lý", "range": [[180, 195], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunrate_v", "name": "Tỷ lệ gây choáng", "range": [[20, 30], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[12, 18], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Giày (Hệ Thổ)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Ngoa", 5, 0, 10, 4, 99999,
        r"\spr\item\equip\boots\obj-shoes120.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (8)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Ngọc bội (Hệ Hỏa)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Yêu Trụy", 9, 1, 10, 3, 99999,
        r"\spr\item\equip\waist\obj-waist109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (9)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Nhẫn dưới (Hệ Hỏa)
    items.append(make_item(
        "Bạch Mã Khiếu Phong Hạ Giới", 3, 0, 10, 3, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Tiêu Dao Kiếm Pháp Hoàng Kim (10)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "attackrating_v", "name": "Độ chính xác", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


# -----------------------------------------------------------------------------
# 5. TIÊU DAO CẦM PHÁP (Hệ Thổ, series = 4, menpai = 12, Group 679, Ext 729)
# -----------------------------------------------------------------------------
def build_tieu_dao_qin_set(start_row: int) -> list[dict]:
    menpai = 12
    req = [["requirelevel", 120], ["requiremenpai", menpai]]
    group, ext = 679, 729
    items = []

    # 1. Dây chuyền
    items.append(make_item(
        "Mai Hoa Lộng Âm Hạng Liên", 4, 1, 10, 3, 99999,
        r"\spr\item\equip\nick\obj-neck109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (1)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[12, 18], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row
    ))

    # 2. Mũ
    items.append(make_item(
        "Mai Hoa Lộng Âm Quán", 7, 4, 10, 4, 99999,
        r"\spr\item\equip\cap\obj-ma-cap120.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (2)",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lightingres_yan_p", "name": "Kháng lôi", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "manareplenish_v", "name": "Hồi phục nội lực", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row + 1
    ))

    # 3. Nhẫn trên
    items.append(make_item(
        "Mai Hoa Lộng Âm Thượng Giới", 3, 0, 10, 3, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (3)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Bao tay
    items.append(make_item(
        "Mai Hoa Lộng Âm Hộ Oản", 8, 1, 10, 4, 99999,
        r"\spr\item\equip\bangle\obj-bangle109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (4)",
        [["armordefense_v", 135, 135], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[25, 35], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Thắt lưng
    items.append(make_item(
        "Mai Hoa Lộng Âm Yêu Đới", 6, 0, 10, 3, 99999,
        r"\spr\item\equip\sash\obj-sash109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (5)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Áo giáp
    items.append(make_item(
        "Mai Hoa Lộng Âm Cầm Y", 2, 4, 10, 4, 99999,
        r"\spr\item\equip\armor\obj-ma-cloth120.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (6)",
        [["armordefense_v", 720, 720], ["durability_v", 90, 90]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[600, 800], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Vũ khí Cầm (Detail 1: Range, Particular 3, Hệ Thổ, Nội công)
    items.append(make_item(
        "Mai Hoa Lộng Âm Cầm", 1, 3, 10, 4, 99999,
        r"\spr\item\equip\closeweapon\obj-lyre04.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (7)",
        [
            ["weapondamagemin_v", 45, 45],
            ["weapondamagemax_v", 88, 88],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 99, 99]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[35, 40], [-1, -1], [0, 0]]},
            {"attrib": "addlightingdamage_v", "name": "Lôi sát nội công", "range": [[200, 240], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[400, 600], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "stunrate_v", "name": "Tỷ lệ gây choáng", "range": [[25, 35], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Giày
    items.append(make_item(
        "Mai Hoa Lộng Âm Ngoa", 5, 0, 10, 4, 99999,
        r"\spr\item\equip\boots\obj-shoes120.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (8)",
        [["armordefense_v", 160, 160], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "stunduration_p", "name": "Giảm thời gian choáng", "range": [[40, 50], [-1, -1], [0, 0]]},
            {"attrib": "block_rate", "name": "Tỷ lệ né tránh", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Ngọc bội
    items.append(make_item(
        "Mai Hoa Lộng Âm Yêu Trụy", 9, 1, 10, 3, 99999,
        r"\spr\item\equip\waist\obj-waist109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (9)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "poisonres_yan_p", "name": "Kháng độc", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "deadlystrike_p", "name": "Chí mạng", "range": [[10, 15], [-1, -1], [0, 0]]},
            {"attrib": "anti_poisonres_yan_p", "name": "Bỏ qua kháng độc", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Nhẫn dưới
    items.append(make_item(
        "Mai Hoa Lộng Âm Hạ Giới", 3, 0, 10, 3, 99999,
        r"\spr\item\equip\ring\obj-ring109.spr", "Bộ trang bị Tiêu Dao Cầm Pháp Hoàng Kim (10)",
        [], req, menpai,
        [
            {"attrib": "allres_yan_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "pk_punish_enhance", "name": "Cường hóa PK", "range": [[105, 115], [-1, -1], [0, 0]]},
            {"attrib": "damage2mana_p", "name": "Chuyển hóa sát thương thành nội lực", "range": [[12, 18], [-1, -1], [0, 0]]},
            {"attrib": "manareplenish_v", "name": "Hồi phục nội lực", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "frozen_action", "name": "Hạn chế động tác", "range": [[13, 13], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


def build_vu_hon_van_loc_the_thu_set(start_row: int) -> list[dict]:
    """Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc (cấp 80, Hệ Hỏa) chuẩn theo ảnh game."""
    menpai = 11
    req = [["requirelevel", 80], ["requiremenpai", menpai]]
    group, ext = 680, 730
    items = []

    # 1. Quán (Mũ) - Món thứ 2 của bộ như trong ảnh
    items.append(make_item(
        "Vân Lộc Thệ Thủ Quán", 7, 4, 10, 3, 49999,
        r"\spr\item\equip\helm\obj-helm109.spr", "Trang bị hoàng kim, món thứ 2 của bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[250, 300], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "skilldamage_enhance_p", "name": "Tăng công kích kỹ năng", "range": [[3, 5], [-1, -1], [0, 0]]},
            {"attrib": "absorb_damage_p", "name": "Xác suất hóa giải sát thương", "range": [[1, 2], [-1, -1], [0, 0]]},
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row
    ))

    # 2. Giáp Y (Áo)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Giáp Y", 2, 4, 10, 3, 49999,
        r"\spr\item\equip\armor\obj-armor08.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [["armordefense_v", 520, 520], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[400, 500], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[30, 40], [-1, -1], [0, 0]]},
            {"attrib": "absorb_damage_p", "name": "Xác suất hóa giải sát thương", "range": [[1, 2], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row + 1
    ))

    # 3. Yêu Đới (Thắt lưng)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Yêu Đới", 6, 0, 10, 3, 49999,
        r"\spr\item\equip\waist\obj-waist09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [["armordefense_v", 120, 120], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "manamax_v", "name": "Nội lực tối đa", "range": [[200, 300], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Thuẫn (Vũ khí Thuẫn Đao - Particular 8)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Thuẫn", 0, 8, 10, 3, 49999,
        r"\spr\item\equip\closeweapon\obj-shield01.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [
            ["weapondamagemin_v", 20, 20],
            ["weapondamagemax_v", 110, 110],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 85, 85]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[30, 35], [-1, -1], [0, 0]]},
            {"attrib": "addfiredamage_v", "name": "Hỏa sát ngoại công", "range": [[150, 200], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "stunrate_v", "name": "Tỷ lệ gây choáng", "range": [[20, 30], [-1, -1], [0, 0]]},
            {"attrib": "absorb_damage_p", "name": "Xác suất hóa giải sát thương", "range": [[2, 3], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 2], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Ngoa (Giày)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Ngoa", 5, 0, 10, 3, 49999,
        r"\spr\item\equip\boots\obj-shoes09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [["armordefense_v", 130, 130], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[35, 40], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Thúc Uyển (Bao tay)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Thúc Uyển", 8, 1, 10, 3, 49999,
        r"\spr\item\equip\bangle\obj-bangle09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [["armordefense_v", 110, 110], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 380], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Hạng Liên (Dây chuyền)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Hạng Liên", 4, 1, 10, 3, 49999,
        r"\spr\item\equip\nick\obj-neck09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Yêu Trụy (Ngọc bội)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Yêu Trụy", 9, 1, 10, 3, 49999,
        r"\spr\item\equip\pendant\obj-pendant09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Hạ Giới (Nhẫn dưới)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Hạ Giới", 3, 0, 10, 3, 49999,
        r"\spr\item\equip\ring\obj-ring09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[250, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Thượng Giới (Nhẫn trên)
    items.append(make_item(
        "Vân Lộc Thệ Thủ Thượng Giới", 3, 0, 10, 3, 49999,
        r"\spr\item\equip\ring\obj-ring09.spr", "Bộ trang bị Vũ Hồn Thuẫn Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[250, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "absorb_damage_p", "name": "Xác suất hóa giải sát thương", "range": [[1, 2], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


def build_vu_hon_van_loc_pha_tran_set(start_row: int) -> list[dict]:
    """Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc (cấp 80, Hệ Hỏa)."""
    menpai = 11
    req = [["requirelevel", 80], ["requiremenpai", menpai]]
    group, ext = 681, 731
    items = []

    # 1. Khôi (Mũ)
    items.append(make_item(
        "Vân Lộc Phá Trận Khôi", 7, 4, 10, 3, 49999,
        r"\spr\item\equip\helm\obj-helm109.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [["armordefense_v", 360, 360], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "skilldamage_enhance_p", "name": "Tăng công kích kỹ năng", "range": [[3, 5], [-1, -1], [0, 0]]},
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 2, ext, start_row
    ))

    # 2. Giáp Y (Áo)
    items.append(make_item(
        "Vân Lộc Phá Trận Giáp Y", 2, 4, 10, 3, 49999,
        r"\spr\item\equip\armor\obj-armor08.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [["armordefense_v", 520, 520], ["durability_v", 85, 85]], req, menpai,
        [
            {"attrib": "physicsres_p", "name": "Kháng vật lý", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[400, 500], [-1, -1], [0, 0]]},
            {"attrib": "fastrecovery_v", "name": "Thời gian phục hồi", "range": [[30, 40], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 1, ext, start_row + 1
    ))

    # 3. Yêu Đới (Thắt lưng)
    items.append(make_item(
        "Vân Lộc Phá Trận Yêu Đới", 6, 0, 10, 3, 49999,
        r"\spr\item\equip\waist\obj-waist09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [["armordefense_v", 120, 120], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 3, ext, start_row + 2
    ))

    # 4. Đao (Vũ khí Đao Thuẫn - Particular 7)
    items.append(make_item(
        "Vân Lộc Phá Trận Đao", 0, 7, 10, 3, 49999,
        r"\spr\item\equip\closeweapon\obj-shield01.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [
            ["weapondamagemin_v", 22, 22],
            ["weapondamagemax_v", 120, 120],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 85, 85]
        ], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[30, 35], [-1, -1], [0, 0]]},
            {"attrib": "addfiredamage_v", "name": "Hỏa sát ngoại công", "range": [[180, 220], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[350, 450], [-1, -1], [0, 0]]},
            {"attrib": "stunrate_v", "name": "Tỷ lệ gây choáng", "range": [[25, 35], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 2], [-1, -1], [0, 0]]}
        ], group, 4, ext, start_row + 3
    ))

    # 5. Ngoa (Giày)
    items.append(make_item(
        "Vân Lộc Phá Trận Ngoa", 5, 0, 10, 3, 49999,
        r"\spr\item\equip\boots\obj-shoes09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [["armordefense_v", 130, 130], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "fastwalkrun_p", "name": "Tốc độ di chuyển", "range": [[35, 40], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 5, ext, start_row + 4
    ))

    # 6. Thúc Uyển (Bao tay)
    items.append(make_item(
        "Vân Lộc Phá Trận Thúc Uyển", 8, 1, 10, 3, 49999,
        r"\spr\item\equip\bangle\obj-bangle09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [["armordefense_v", 110, 110], ["durability_v", 80, 80]], req, menpai,
        [
            {"attrib": "attackspeed_v", "name": "Tốc độ xuất chiêu", "range": [[25, 30], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 380], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 6, ext, start_row + 5
    ))

    # 7. Hạng Liên (Dây chuyền)
    items.append(make_item(
        "Vân Lộc Phá Trận Hạng Liên", 4, 1, 10, 3, 49999,
        r"\spr\item\equip\nick\obj-neck09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 7, ext, start_row + 6
    ))

    # 8. Yêu Trụy (Ngọc bội)
    items.append(make_item(
        "Vân Lộc Phá Trận Yêu Trụy", 9, 1, 10, 3, 49999,
        r"\spr\item\equip\pendant\obj-pendant09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "allres_p", "name": "Kháng tất cả", "range": [[15, 20], [-1, -1], [0, 0]]},
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[300, 400], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 8, ext, start_row + 7
    ))

    # 9. Hạ Giới (Nhẫn dưới)
    items.append(make_item(
        "Vân Lộc Phá Trận Hạ Giới", 3, 0, 10, 3, 49999,
        r"\spr\item\equip\ring\obj-ring09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[250, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "stuntimereduce_p", "name": "Thời gian choáng", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 9, ext, start_row + 8
    ))

    # 10. Thượng Giới (Nhẫn trên)
    items.append(make_item(
        "Vân Lộc Phá Trận Thượng Giới", 3, 0, 10, 3, 49999,
        r"\spr\item\equip\ring\obj-ring09.spr", "Bộ trang bị Vũ Hồn Đao Pháp cấp Vân Lộc",
        [], req, menpai,
        [
            {"attrib": "lifemax_v", "name": "Sinh lực tối đa", "range": [[250, 350], [-1, -1], [0, 0]]},
            {"attrib": "fireres_p", "name": "Kháng hỏa", "range": [[20, 25], [-1, -1], [0, 0]]},
            {"attrib": "skilldamage_enhance_p", "name": "Tăng công kích kỹ năng", "range": [[3, 5], [-1, -1], [0, 0]]},
            {"attrib": "allskill_v", "name": "Tăng tất cả kỹ năng", "range": [[1, 1], [-1, -1], [0, 0]]}
        ], group, 10, ext, start_row + 9
    ))
    return items


# -----------------------------------------------------------------------------
# 9-10. VŨ HỒN THUẪN CỰC PHẨM "Trấn Nhạc" — 2 bộ x 6 món (theo ảnh game, menpai = 11)
#   Bộ 1 (Group 682): Giáp, Đái, Thuẫn, Uyển, [TB] Ngọc Bội, Giới — dòng bộ: Tăng sát thương đối với hệ Kim
#   Bộ 2 (Group 683): Khôi, Ngoa, Phù, Khấu, Giới + Hộ Tâm Uyển (món 6 tự đặt, ảnh gốc không có) — dòng bộ: Giảm sát thương đến từ hệ Kim
# Hình: sash06 (đai) và shoes05 (giày) khớp đúng ảnh; các món khác là hình riêng của server gốc, không có trong
# client 15 phái -> tạm dùng hình gần giống nhất.
# -----------------------------------------------------------------------------
TRAN_NHAC_SPREAD = 0.05
## Mã skill Vũ Hồn (Skills.txt bản 15 phái) cho dòng "Kỹ năng [<tên>] +N cấp"; 0 = Võ công vốn có.
VH_VU_MUC_DI_THU, VH_THUAN_PHAP, VH_TRIEU_THIEN_KHUYET = 1982, 1964, 1963
VH_DOAT_CO, VH_TRAN_BIEN_THUY, VH_THINH_ANH = 1972, 1967, 1965


def _tn_line(attrib, name, value, skill_id=0):
    return {"attrib": attrib, "name": name, "range": [[value, value], [-1, -1], [skill_id, skill_id]]}


def _tn_skill(level, skill_id=0):
    return _tn_line("allskill_v", "Kỹ năng", level, skill_id)


def _tn_item(name, detail, particular, series, level, strength, image, intro, base, magic, group, set_id, ext, row,
             menpai=11, set_size=6):
    ## 6 dòng thường roll ±5% (đồ rơi dùng generate_gold_random); cố định: cấp kỹ năng, "Không thể phá hủy",
    ## 2 dòng bộ và chỉ số gốc.
    for ln in magic[:6]:
        if ln and ln["attrib"] not in ("allskill_v", "indestructible_b"):
            v = ln["range"][0][0]
            ln["range"][0] = [round(v * (1 - TRAN_NHAC_SPREAD)), round(v * (1 + TRAN_NHAC_SPREAD))]
    req = [["requirelevel", level], ["requiremenpai", menpai]]
    if strength:
        req.append(["requirestr", strength])
    it = make_item(name, detail, particular, 10, series, 99999, image, intro, base, req, menpai, magic, group, set_id, ext, row)
    ## Bộ 5-6 món: mỗi 3 món bật 1 dòng bộ, đủ bộ bật hết.
    it["need1"], it["need2"] = 3, set_size
    return it


def build_vu_hon_tran_nhac_set1(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 682, 732
    intro = "Bộ HKMP Vũ Hồn thuẫn cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("me2metaldamage_p", "Tăng sát thương đối với hệ Kim", 1)]

    def item(name, detail, particular, series, level, strength, image, base, magic, set_id, intro_text=intro):
        return _tn_item(name, detail, particular, series, level, strength, image, intro_text, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1)

    return [
        item("Trấn Nhạc Uy Vũ Giáp", 2, 4, KIM, 90, 260, r"\spr\item\equip\armor\obj-ma-cloth23.spr",
             [["armordefense_v", 720, 720], ["durability_v", 90, 90]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fasthitrecover_v", "Thời gian phục hồi", 50),
            _tn_skill(3, VH_THUAN_PHAP),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_skill(3, VH_TRIEU_THIEN_KHUYET),
        ], 1),
        item("Trấn Nhạc Long Lân Đái", 6, 0, THO, 95, 135, r"\spr\item\equip\sash\obj-sash06.spr",
             [["armordefense_v", 160, 160], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_skill(3, VH_DOAT_CO),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_skill(3, VH_TRAN_BIEN_THUY),
        ], 2),
        ## Vũ khí Thuẫn đao (Particular 8).
        item("Trấn Nhạc Kim Cương Thuẫn", 0, 8, THUY, 99, 138, r"\spr\item\equip\closeweapon\obj-shield05.spr", [
            ["weapondamagemin_v", 20, 20],
            ["weapondamagemax_v", 150, 150],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 99, 99],
        ], [
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 100),
            _tn_line("addphysicsdamage_v", "Sát thương vật lý - ngoại công", 50),
            _tn_line("stealmanaenhance_p", "Hút nội lực", 8),
            _tn_line("addcolddamage_v", "Băng sát - ngoại công", 120),
            _tn_line("attackspeed_v", "Tốc độ đánh - ngoại công", 40),
            _tn_skill(3, VH_VU_MUC_DI_THU),
        ], 3),
        item("Trấn Nhạc Hào Hùng Uyển", 8, 1, HOA, 85, 110, r"\spr\item\equip\bangle\obj-bangle103.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_skill(3, VH_THINH_ANH),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 50),
        ], 4),
        item("[TB] Trấn Nhạc Lưu Quang Ngọc Bội", 9, 1, HOA, 120, 0, r"\spr\item\equip\waist\obj-waist115.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("anti_fireres_p", "Bỏ qua kháng hỏa đối phương", 15),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 50),
            _tn_skill(3, VH_TRAN_BIEN_THUY),
            _tn_skill(3, VH_THUAN_PHAP),
        ], 5, "Trấn bang chi bảo Vũ Hồn thuẫn cực phẩm"),
        item("Trấn Nhạc Định Tâm Giới", 3, 0, MOC, 80, 0, r"\spr\item\equip\ring\obj-ring116.spr", [], [
            _tn_line("indestructible_b", "Không thể phá hủy", 1),
            _tn_skill(1),
            None, None, None, None,
        ], 6),
    ]


def build_vu_hon_tran_nhac_set2(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 683, 733
    intro = "Bộ HKMP 2 Vũ Hồn thuẫn cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("metal2medamage_p", "Giảm sát thương đến từ hệ Kim", 1)]

    def item(name, detail, particular, series, image, base, magic, set_id):
        return _tn_item(name, detail, particular, series, 120, 0, image, intro, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1)

    return [
        item("Trấn Nhạc Khiếu Nguyệt Khôi", 7, 4, THUY, r"\spr\item\equip\cap\obj-ma-cap24.spr",
             [["armordefense_v", 315, 315], ["durability_v", 85, 85]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("poisonres_p", "Kháng độc", 25),
        ], 1),
        item("Trấn Nhạc Truy Phong Ngoa", 5, 0, MOC, r"\spr\item\equip\boots\obj-shoes05.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fastwalkrun_p", "Tốc độ di chuyển", 50),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("vitality_v", "Sinh khí", 20),
        ], 2),
        item("Trấn Nhạc Phá Quân Phù", 4, 1, KIM, r"\spr\item\equip\nick\obj-neck117.spr", [], [
            _tn_line("allres_p", "Kháng tất cả", 24),
            _tn_line("fireres_p", "Kháng hỏa", 25),
            _tn_line("lightingres_p", "Kháng lôi", 25),
            _tn_line("poisonres_p", "Kháng độc", 25),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 40),
        ], 3),
        item("Trấn Nhạc Phần Thiên Khấu", 9, 1, HOA, r"\spr\item\equip\waist\obj-waist110.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fireres_p", "Kháng hỏa", 15),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_line("allres_p", "Kháng tất cả", 5),
            _tn_line("dexterity_v", "Thân pháp", 20),
        ], 4),
        item("Trấn Nhạc Chấn Thiên Giới", 3, 0, THO, r"\spr\item\equip\ring\obj-ring117.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_skill(1),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("coldres_p", "Kháng băng", 25),
            _tn_line("allres_p", "Kháng tất cả", 5),
            _tn_line("energy_v", "Nội công", 20),
        ], 5),
        ## Món thứ 6: ảnh gốc không có -> người dùng cho tự đặt (2026-11-25). Bao tay (ô bộ 2 còn trống), chỉ số theo
        ## khuôn bộ 2: Sinh lực/Nội lực 200, 1 kháng, 1 giảm thời gian xấu, ngoại công 50%, +20 điểm tiềm năng.
        item("Trấn Nhạc Hộ Tâm Uyển", 8, 1, KIM, r"\spr\item\equip\bangle\obj-bangle109.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("lightingres_p", "Kháng lôi", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("strength_v", "Sức mạnh", 20),
        ], 6),
    ]


# -----------------------------------------------------------------------------
# 11-12. VŨ HỒN ĐAO CỰC PHẨM "Khai Sơn" — 2 bộ x 6 món (theo ảnh game, menpai = 11)
#   Bộ 1 (Group 684): Giáp, Đái, Đao, [TB] Chiến Ngoa, Uyển, Giới — dòng bộ: Tăng sát thương đối với hệ Kim
#   Bộ 2 (Group 685): Khôi, Ngoa, Phù, Bội, Giới + Phá Trận Uyển (món 6 tự đặt, ảnh gốc không có)
#                     — dòng bộ: Giảm sát thương đến từ hệ Kim
# Hình: shoes05 (Truy Vân Ngoa) khớp ảnh; còn lại là hình riêng server gốc -> tạm dùng hình gần giống.
# -----------------------------------------------------------------------------
VH_DAO_PHAP, VH_KHAT_AM, VH_TRUONG_ANH, VH_NO_PHACH, VH_HAM_SON = 1975, 1983, 1974, 1979, 1977


def build_vu_hon_khai_son_set1(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 684, 734
    intro = "Bộ HKMP Vũ Hồn đao cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("me2metaldamage_p", "Tăng sát thương đối với hệ Kim", 1)]

    def item(name, detail, particular, series, level, strength, image, base, magic, set_id, intro_text=intro):
        return _tn_item(name, detail, particular, series, level, strength, image, intro_text, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1)

    return [
        item("Khai Sơn Kình Thiên Giáp", 2, 4, KIM, 90, 260, r"\spr\item\equip\armor\obj-ma-cloth23.spr",
             [["armordefense_v", 720, 720], ["durability_v", 90, 90]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fasthitrecover_v", "Thời gian phục hồi", 50),
            _tn_skill(3, VH_DAO_PHAP),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_skill(3, VH_NO_PHACH),
        ], 1),
        item("Khai Sơn Liên Hoàn Đái", 6, 0, THO, 95, 135, r"\spr\item\equip\sash\obj-ma-sash116.spr",
             [["armordefense_v", 160, 160], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_skill(3, VH_TRUONG_ANH),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_skill(3, VH_KHAT_AM),
        ], 2),
        ## Vũ khí Đao thuẫn (Particular 7).
        item("Khai Sơn Trảm Tướng Đao", 0, 7, THUY, 99, 138, r"\spr\item\equip\closeweapon\obj-shield04.spr", [
            ["weapondamagemin_v", 25, 25],
            ["weapondamagemax_v", 160, 160],
            ["attackratingenhance_p", 30, 30],
            ["durability_v", 99, 99],
        ], [
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 100),
            _tn_line("addphysicsdamage_v", "Sát thương vật lý - ngoại công", 50),
            _tn_line("stealmanaenhance_p", "Hút nội lực", 8),
            _tn_line("addcolddamage_v", "Băng sát - ngoại công", 120),
            _tn_line("attackspeed_v", "Tốc độ đánh - ngoại công", 40),
            _tn_skill(3, VH_VU_MUC_DI_THU),
        ], 3),
        item("[TB] Khai Sơn Đạp Thiên Chiến Ngoa", 5, 0, MOC, 120, 135, r"\spr\item\equip\boots\obj-shoes114.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fastwalkrun_p", "Tốc độ di chuyển", 50),
            _tn_line("anti_fireres_p", "Bỏ qua kháng hỏa đối phương", 15),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_skill(3, VH_KHAT_AM),
            _tn_skill(3, VH_DAO_PHAP),
        ], 4, "Trấn bang chi bảo Vũ Hồn đao cực phẩm"),
        item("Khai Sơn Toái Cốt Uyển", 8, 1, HOA, 85, 110, r"\spr\item\equip\bangle\obj-bangle106.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_skill(3, VH_HAM_SON),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 50),
        ], 5),
        item("Khai Sơn Hùng Tâm Giới", 3, 0, MOC, 80, 0, r"\spr\item\equip\ring\obj-ring116.spr", [], [
            _tn_line("indestructible_b", "Không thể phá hủy", 1),
            _tn_skill(1),
            None, None, None, None,
        ], 6),
    ]


def build_vu_hon_khai_son_set2(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 685, 735
    intro = "Bộ HKMP 2 Vũ Hồn đao cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("metal2medamage_p", "Giảm sát thương đến từ hệ Kim", 1)]

    def item(name, detail, particular, series, image, base, magic, set_id):
        return _tn_item(name, detail, particular, series, 120, 0, image, intro, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1)

    return [
        item("Khai Sơn Liệt Nhật Khôi", 7, 4, THUY, r"\spr\item\equip\cap\obj-ma-cap117.spr",
             [["armordefense_v", 315, 315], ["durability_v", 85, 85]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("poisonres_p", "Kháng độc", 25),
        ], 1),
        item("Khai Sơn Truy Vân Ngoa", 5, 0, MOC, r"\spr\item\equip\boots\obj-shoes05.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fastwalkrun_p", "Tốc độ di chuyển", 50),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("vitality_v", "Sinh khí", 20),
        ], 2),
        item("Khai Sơn Liệt Địa Phù", 4, 1, KIM, r"\spr\item\equip\nick\obj-neck117.spr", [], [
            _tn_line("allres_p", "Kháng tất cả", 24),
            _tn_line("fireres_p", "Kháng hỏa", 25),
            _tn_line("lightingres_p", "Kháng lôi", 25),
            _tn_line("poisonres_p", "Kháng độc", 25),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 40),
        ], 3),
        item("Khai Sơn Kinh Lôi Bội", 9, 1, HOA, r"\spr\item\equip\waist\obj-waist116.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fireres_p", "Kháng hỏa", 15),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_line("allres_p", "Kháng tất cả", 5),
            _tn_line("dexterity_v", "Thân pháp", 20),
        ], 4),
        item("Khai Sơn Toái Ngọc Giới", 3, 0, THO, r"\spr\item\equip\ring\obj-ring117.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_skill(1),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("coldres_p", "Kháng băng", 25),
            _tn_line("allres_p", "Kháng tất cả", 5),
            _tn_line("energy_v", "Nội công", 20),
        ], 5),
        ## Món thứ 6 tự đặt (giống Trấn Nhạc Hộ Tâm Uyển): bao tay, khuôn chỉ số bộ 2, +20 Sức mạnh.
        item("Khai Sơn Phá Trận Uyển", 8, 1, KIM, r"\spr\item\equip\bangle\obj-bangle109.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("lightingres_p", "Kháng lôi", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_line("addphysicsdamage_p", "Sát thương vật lý - ngoại công", 50),
            _tn_line("strength_v", "Sức mạnh", 20),
        ], 6),
    ]


# -----------------------------------------------------------------------------
# 13-14. TIÊU DAO CẦM CỰC PHẨM "Huyền Âm" (theo ảnh game, menpai = 12)
#   Bộ 1 (Group 686, 6 món): Uẩn Linh Y, [TB] Mộng Ảo Đoạt Hồn Đái, Thiên Ma Cầm, Lưu Ly Bội, Định Tâm Hoàn,
#                            Tố Tâm Giới — dòng bộ: Tăng sát thương đối với hệ Thủy
#   Bộ 2 (Group 687, 5 món): Ngọc Tiêu Quán, Thính Vũ Y, Lăng Ba Ngoa, Vấn Tâm Uyển, Vọng Nguyệt Phù
#                            — dòng bộ: Giảm sát thương đến từ hệ Thủy
# Hình ô đồ: hình riêng server gốc không có trong client -> tạm dùng hình gần giống. Ngoài map: áo/mũ Tiêu Dao 82/56.
# -----------------------------------------------------------------------------
TD_THIEN_LY, TD_CAM_PHAP, TD_HIEP_COT, TD_TUY_Y = 1890, 1906, 1889, 1905
TD_CAO_SON, TD_LAC_NHAN, TD_QUANG_LANG = 1910, 1907, 1909


def build_tieu_dao_huyen_am_set1(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 686, 736
    intro = "Bộ HKMP Tiêu Dao cầm cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("me2waterdamage_p", "Tăng sát thương đối với hệ Thủy", 1)]

    def item(name, detail, particular, series, level, strength, image, base, magic, set_id, intro_text=intro):
        return _tn_item(name, detail, particular, series, level, strength, image, intro_text, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1, menpai=12, set_size=6)

    return [
        item("Huyền Âm Uẩn Linh Y", 2, 4, HOA, 95, 130, r"\spr\item\equip\armor\obj-ma-cloth133.spr",
             [["armordefense_v", 630, 630], ["durability_v", 90, 90]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fasthitrecover_v", "Thời gian phục hồi", 50),
            _tn_skill(3, TD_CAM_PHAP),
            _tn_line("poisonres_p", "Kháng độc", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_skill(3, TD_HIEP_COT),
        ], 1),
        item("[TB] Huyền Âm Mộng Ảo Đoạt Hồn Đái", 6, 0, MOC, 120, 110, r"\spr\item\equip\sash\obj-sash110.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("anti_stuntimereduce_p", "Tăng thời gian choáng", 50),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 240),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 50),
            _tn_skill(3, TD_CAM_PHAP),
            _tn_line("addlightingmagic_v", "Lôi sát - nội công", 300),
        ], 2, "Trấn bang chi bảo Tiêu Dao cầm cực phẩm"),
        ## Vũ khí Cầm (Ám khí, Particular 3).
        item("Huyền Âm Thiên Ma Cầm", 1, 3, THO, 90, 100, r"\spr\item\equip\closeweapon\obj-lyre04.spr", [
            ["weapondamagemin_v", 48, 48],
            ["weapondamagemax_v", 85, 85],
            ["durability_v", 99, 99],
        ], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("addlightingmagic_v", "Lôi sát - nội công", 300),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("fireres_p", "Kháng hỏa", 30),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 50),
            _tn_skill(3, TD_THIEN_LY),
        ], 3),
        item("Huyền Âm Lưu Ly Bội", 9, 1, THUY, 99, 0, r"\spr\item\equip\waist\obj-waist114.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_skill(3, TD_CAO_SON),
            _tn_skill(3, TD_LAC_NHAN),
            _tn_line("poisonres_p", "Kháng độc", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 400),
            _tn_skill(3, TD_QUANG_LANG),
        ], 4),
        item("Huyền Âm Định Tâm Hoàn", 3, 0, KIM, 80, 0, r"\spr\item\equip\ring\obj-ring109.spr", [], [
            _tn_line("indestructible_b", "Không thể phá hủy", 1),
            _tn_skill(1),
            None, None, None, None,
        ], 5),
        item("Huyền Âm Tố Tâm Giới", 3, 0, MOC, 85, 0, r"\spr\item\equip\ring\obj-ring117.spr", [], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_skill(3, TD_TUY_Y),
            _tn_line("poisonres_p", "Kháng độc", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("stuntimereduce_p", "Thời gian choáng", 40),
        ], 6),
    ]


def build_tieu_dao_huyen_am_set2(start_row: int) -> list[dict]:
    KIM, MOC, THUY, HOA, THO = 0, 1, 2, 3, 4
    group, ext = 687, 737
    intro = "Bộ HKMP 2 Tiêu Dao cầm cực phẩm"
    set_lines = [_tn_line("lifemax_v", "Sinh lực tối đa", 100), _tn_line("water2medamage_p", "Giảm sát thương đến từ hệ Thủy", 1)]

    def item(name, detail, particular, series, image, base, magic, set_id):
        return _tn_item(name, detail, particular, series, 120, 0, image, intro, base,
                        magic + [dict(x, range=[list(r) for r in x["range"]]) for x in set_lines],
                        group, set_id, ext, start_row + set_id - 1, menpai=12, set_size=5)

    return [
        item("Huyền Âm Ngọc Tiêu Quán", 7, 4, THO, r"\spr\item\equip\cap\obj-ma-cap132.spr",
             [["armordefense_v", 315, 315], ["durability_v", 85, 85]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("lightingres_p", "Kháng lôi", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("freezetimereduce_p", "Thời gian làm chậm", 50),
            _tn_line("coldres_p", "Kháng băng", 30),
            _tn_line("energy_v", "Nội công", 20),
        ], 1),
        item("Huyền Âm Thính Vũ Y", 2, 4, HOA, r"\spr\item\equip\armor\obj-ma-cloth134.spr",
             [["armordefense_v", 630, 630], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fasthitrecover_v", "Thời gian phục hồi", 60),
            _tn_line("poisontimereduce_p", "Thời gian trúng độc", 50),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("fireres_p", "Kháng hỏa", 30),
        ], 2),
        item("Huyền Âm Lăng Ba Ngoa", 5, 0, KIM, r"\spr\item\equip\boots\obj-shoes05.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("fastwalkrun_p", "Tốc độ di chuyển", 50),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("addlightingmagic_v", "Lôi sát - nội công", 120),
            _tn_line("strength_v", "Sức mạnh", 20),
        ], 3),
        item("Huyền Âm Vấn Tâm Uyển", 8, 1, THUY, r"\spr\item\equip\bangle\obj-ma-bangle114.spr",
             [["armordefense_v", 140, 140], ["durability_v", 80, 80]], [
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_skill(1),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("poisonres_p", "Kháng độc", 25),
            _tn_line("allres_p", "Kháng tất cả", 5),
            _tn_line("vitality_v", "Sinh khí", 20),
        ], 4),
        item("Huyền Âm Vọng Nguyệt Phù", 4, 1, HOA, r"\spr\item\equip\nick\obj-neck116.spr", [], [
            _tn_line("allres_p", "Kháng tất cả", 24),
            _tn_line("poisonres_p", "Kháng độc", 30),
            _tn_line("manamax_v", "Nội lực tối đa", 200),
            _tn_line("physicsres_p", "Phòng thủ vật lý", 30),
            _tn_line("lifemax_v", "Sinh lực tối đa", 200),
            _tn_line("lightingres_p", "Kháng lôi", 50),
        ], 5),
    ]
