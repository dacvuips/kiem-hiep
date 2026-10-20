"""Cập nhật thông tin Boss chuẩn từ source võ lâm gốc 'Anh-viet' vào data/monsters/monsters.json.

Nguồn đối chiếu:
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Npcs.txt
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/NpcName.txt
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/header/bosstieuhk.lua
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/header/vuotai.lua
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/header/phonglangdo.lua
- D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/startgame/khac/satthu.lua
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MONSTERS_JSON = os.path.join(ROOT, "data", "monsters", "monsters.json")

# Định nghĩa thông tin chi tiết của các boss lấy từ source võ lâm Anh-Việt
BOSS_METADATA = {
    # --- THẬP ĐẠI BOSS HOÀNG KIM (ĐẠI HOÀNG KIM) ---
    "566": {
        "name": "Cổ Bách",
        "title": "Thiên Vương Bang Chủ",
        "sect": "Thiên Vương",
        "series": 0,
        "is_boss": True,
        "boss_type": "gold",
    },
    "740": {
        "name": "Huyền Giác Đại Sư",
        "title": "Thiếu Lâm Phương Trượng",
        "sect": "Thiếu Lâm",
        "series": 0,
        "is_boss": True,
        "boss_type": "gold",
    },
    "741": {
        "name": "Đường Bất Nhiễm",
        "title": "Đường Môn Trưởng Lão",
        "sect": "Đường Môn",
        "series": 1,
        "is_boss": True,
        "boss_type": "gold",
    },
    "742": {
        "name": "Bạch Doanh Doanh",
        "title": "Đường Môn Tuyệt Sắc",
        "sect": "Đường Môn",
        "series": 1,
        "is_boss": True,
        "boss_type": "gold",
    },
    "582": {
        "name": "Lam Y Y",
        "title": "Ngũ Độc Giáo Chủ",
        "sect": "Ngũ Độc",
        "series": 1,
        "is_boss": True,
        "boss_type": "gold",
    },
    "743": {
        "name": "Thanh Tiếu Sư Thái",
        "title": "Nga Mi Chưởng Môn",
        "sect": "Nga Mi",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "568": {
        "name": "Hà Linh Phiêu",
        "title": "Nga Mi Cao Thủ",
        "sect": "Nga Mi",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "567": {
        "name": "Chung Linh Tú",
        "title": "Thúy Yên Môn Chủ",
        "sect": "Thúy Yên",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "744": {
        "name": "Yên Hiểu Trái",
        "title": "Thúy Yên Hộ Pháp",
        "sect": "Thúy Yên",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "583": {
        "name": "Mạnh Thương Lương",
        "title": "Cái Bang Bang Chủ",
        "sect": "Cái Bang",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "745": {
        "name": "Hà Nhân Ngã",
        "title": "Cái Bang Trưởng Lão",
        "sect": "Cái Bang",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "563": {
        "name": "Gia Luật Tị Ly",
        "title": "Thiên Nhẫn Giáo Chủ",
        "sect": "Thiên Nhẫn",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "564": {
        "name": "Hoàn Nhan Tuyết Y",
        "title": "Kim Quốc Công Chúa",
        "sect": "Thiên Nhẫn",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "565": {
        "name": "Đoan Mộc Duệ",
        "title": "Thiên Nhẫn Tả Sứ",
        "sect": "Thiên Nhẫn",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "562": {
        "name": "Đạo Thanh Chân Nhân",
        "title": "Võ Đang Chưởng Môn",
        "sect": "Võ Đang",
        "series": 4,
        "is_boss": True,
        "boss_type": "gold",
    },
    "746": {
        "name": "Sơn Tư Nam",
        "title": "Côn Lôn Kiếm Thần",
        "sect": "Côn Lôn",
        "series": 4,
        "is_boss": True,
        "boss_type": "gold",
    },
    "747": {
        "name": "Tuyền Cơ Tử",
        "title": "Côn Lôn Chưởng Môn",
        "sect": "Côn Lôn",
        "series": 4,
        "is_boss": True,
        "boss_type": "gold",
    },

    # --- TIỂU HOÀNG KIM BOSS (bosstieuhk.lua) ---
    "511": {
        "name": "Trương Tông Chính",
        "title": "Tiểu Hoàng Kim Côn Lôn",
        "sect": "Côn Lôn",
        "series": 4,
        "is_boss": True,
        "boss_type": "small_gold",
    },
    "513": {
        "name": "Diệu Như",
        "title": "Tiểu Hoàng Kim Nga Mi",
        "sect": "Nga Mi",
        "series": 2,
        "is_boss": True,
        "boss_type": "small_gold",
    },
    "523": {
        "name": "Liễu Thanh Thanh",
        "title": "Tiểu Hoàng Kim Thúy Yên",
        "sect": "Thúy Yên",
        "series": 1,
        "is_boss": True,
        "boss_type": "small_gold",
    },

    # --- TÂN BOSS HOÀNG KIM 10 MÔN PHÁI (STT 1193 - 1202 & 1222 - 1231) ---
    "1193": {
        "name": "Cổ Bách (Thiên Vương)",
        "title": "Thương Pháp Vô Song",
        "sect": "Thiên Vương",
        "series": 0,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1194": {
        "name": "Huyền Giác Thiền Sư (Thiếu Lâm)",
        "title": "Kim Cương Bất Hoại",
        "sect": "Thiếu Lâm",
        "series": 0,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1195": {
        "name": "Đường Bất Nhiễm (Đường Môn)",
        "title": "Truy Hồn Đoạt Phách",
        "sect": "Đường Môn",
        "series": 1,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1196": {
        "name": "Lam Y Y (Ngũ Độc)",
        "title": "Vạn Cổ Đoạt Mệnh",
        "sect": "Ngũ Độc",
        "series": 1,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1197": {
        "name": "Thanh Hiểu Sư Thái (Nga Mi)",
        "title": "Băng Tâm Kiếm Thần",
        "sect": "Nga Mi",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1198": {
        "name": "Chung Linh Tú (Thúy Yên)",
        "title": "Băng Phong Tuyết Vũ",
        "sect": "Thúy Yên",
        "series": 2,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1199": {
        "name": "Hà Nhân Ngã (Cái Bang)",
        "title": "Hàng Long Phục Hổ",
        "sect": "Cái Bang",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1200": {
        "name": "Đoan Mộc Duệ (Thiên Nhẫn)",
        "title": "Ma Diễm Liệt Hỏa",
        "sect": "Thiên Nhẫn",
        "series": 3,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1201": {
        "name": "Đạo Thanh Chân Nhân (Võ Đang)",
        "title": "Thái Cực Kiếm Tôn",
        "sect": "Võ Đang",
        "series": 4,
        "is_boss": True,
        "boss_type": "gold",
    },
    "1202": {
        "name": "Tuyền Cơ Tử (Côn Lôn)",
        "title": "Côn Lôn Kiếm Tôn",
        "sect": "Côn Lôn",
        "series": 4,
        "is_boss": True,
        "boss_type": "gold",
    },

    "1222": {"name": "Chung Linh Tú (Thúy Yên Đao)", "sect": "Thúy Yên", "series": 2, "is_boss": True, "boss_type": "gold"},
    "1223": {"name": "Thanh Hiểu Sư Thái (Phụ Trợ)", "sect": "Nga Mi", "series": 2, "is_boss": True, "boss_type": "gold"},
    "1224": {"name": "Hà Nhân Ngã (Bổng Pháp)", "sect": "Cái Bang", "series": 3, "is_boss": True, "boss_type": "gold"},
    "1225": {"name": "Tuyền Cơ Tử (Kiếm Pháp)", "sect": "Côn Lôn", "series": 4, "is_boss": True, "boss_type": "gold"},
    "1226": {"name": "Huyền Giác Thiền Sư (Quyền Pháp)", "sect": "Thiếu Lâm", "series": 0, "is_boss": True, "boss_type": "gold"},
    "1227": {"name": "Đường Bất Nhiễm (Phi Đao)", "sect": "Đường Môn", "series": 1, "is_boss": True, "boss_type": "gold"},
    "1228": {"name": "Đạo Thanh Chân Nhân (Kiếm Pháp)", "sect": "Võ Đang", "series": 4, "is_boss": True, "boss_type": "gold"},
    "1229": {"name": "Cổ Bách (Chùy Pháp)", "sect": "Thiên Vương", "series": 0, "is_boss": True, "boss_type": "gold"},
    "1230": {"name": "Gia Luật Tị Ly (Đao Pháp)", "sect": "Thiên Nhẫn", "series": 3, "is_boss": True, "boss_type": "gold"},
    "1231": {"name": "Đạo Thanh Chân Nhân (Khí Tông)", "sect": "Võ Đang", "series": 4, "is_boss": True, "boss_type": "gold"},

    # --- BOSS VƯỢT ẢI (vuotai.lua & STT 1674 - 1683) ---
    "1026": {"name": "Nguyệt Ảnh", "title": "Thủ Ải Thần Tướng", "series": 2, "is_boss": True, "boss_type": "challenge"},
    "1027": {"name": "Huyền Âm", "title": "Thủ Ải Thần Tướng", "series": 4, "is_boss": True, "boss_type": "challenge"},
    "1028": {"name": "Bát Hoang", "title": "Thủ Ải Thần Tướng", "series": 0, "is_boss": True, "boss_type": "challenge"},
    "1029": {"name": "Lục Long", "title": "Thủ Ải Thần Tướng", "series": 3, "is_boss": True, "boss_type": "challenge"},
    "1030": {"name": "Cuồng Phong", "title": "Thủ Ải Thần Tướng", "series": 4, "is_boss": True, "boss_type": "challenge"},
    "1031": {"name": "Tinh Hỏa", "title": "Thủ Ải Thần Tướng", "series": 3, "is_boss": True, "boss_type": "challenge"},
    "1032": {"name": "Càn Khôn", "title": "Thủ Ải Thần Tướng", "series": 1, "is_boss": True, "boss_type": "challenge"},
    "1033": {"name": "Vi Đà", "title": "Thủ Ải Thần Tướng", "series": 0, "is_boss": True, "boss_type": "challenge"},
    "1034": {"name": "Băng Tước", "title": "Thủ Ải Thần Tướng", "series": 2, "is_boss": True, "boss_type": "challenge"},
    "1035": {"name": "Tật Hỏa", "title": "Thủ Ải Thần Tướng", "series": 3, "is_boss": True, "boss_type": "challenge"},
    "1036": {"name": "U Hồn", "title": "Thủ Ải Thần Tướng", "series": 4, "is_boss": True, "boss_type": "challenge"},
    "1037": {"name": "Nhiếp Hồn", "title": "Thủ Ải Thần Tướng", "series": 2, "is_boss": True, "boss_type": "challenge"},
    "1038": {"name": "Độc Cô Cầu Kiếm", "title": "Trấn Ải Tuyệt Đỉnh Ma Tôn", "series": 0, "is_boss": True, "boss_type": "challenge"},

    "1674": {"name": "Vượt Ải - Cổ Bách", "sect": "Thiên Vương", "series": 0, "is_boss": True, "boss_type": "challenge"},
    "1675": {"name": "Vượt Ải - Huyền Giác Đại Sư", "sect": "Thiếu Lâm", "series": 0, "is_boss": True, "boss_type": "challenge"},
    "1676": {"name": "Vượt Ải - Đường Bất Nhiễm", "sect": "Đường Môn", "series": 1, "is_boss": True, "boss_type": "challenge"},
    "1677": {"name": "Vượt Ải - Lam Y Y", "sect": "Ngũ Độc", "series": 1, "is_boss": True, "boss_type": "challenge"},
    "1678": {"name": "Vượt Ải - Thanh Hiểu Sư Thái", "sect": "Nga Mi", "series": 2, "is_boss": True, "boss_type": "challenge"},
    "1679": {"name": "Vượt Ải - Chung Linh Tú", "sect": "Thúy Yên", "series": 2, "is_boss": True, "boss_type": "challenge"},
    "1680": {"name": "Vượt Ải - Hà Nhân Ngã", "sect": "Cái Bang", "series": 3, "is_boss": True, "boss_type": "challenge"},
    "1681": {"name": "Vượt Ải - Đoan Mộc Duệ", "sect": "Thiên Nhẫn", "series": 3, "is_boss": True, "boss_type": "challenge"},
    "1682": {"name": "Vượt Ải - Đạo Thanh Chân Nhân", "sect": "Võ Đang", "series": 4, "is_boss": True, "boss_type": "challenge"},
    "1683": {"name": "Vượt Ải - Tuyền Cơ Tử", "sect": "Côn Lôn", "series": 4, "is_boss": True, "boss_type": "challenge"},

    # --- BOSS SÁT THỦ (satthu.lua) ---
    "809": {"name": "Tăng Chi Oán", "title": "Sát Thủ Lão Hổ Động", "series": 1, "is_boss": True, "boss_type": "killer"},
    "810": {"name": "Vệ Biên Thành", "title": "Sát Thủ Lão Hổ Động", "series": 0, "is_boss": True, "boss_type": "killer"},
    "811": {"name": "Cổ Thủ Đăng", "title": "Sát Thủ Sa Mạc Địa Biểu", "series": 3, "is_boss": True, "boss_type": "killer"},
    "812": {"name": "Gia Cát Kinh Hồng", "title": "Sát Thủ Sa Mạc Địa Biểu", "series": 4, "is_boss": True, "boss_type": "killer"},
    "813": {"name": "Trang Minh Trung", "title": "Sát Thủ Hoàng Hà Nguyên Đầu", "series": 2, "is_boss": True, "boss_type": "killer"},
    "814": {"name": "Liễu Tứ Gia", "title": "Sát Thủ Vũ Di Sơn", "series": 1, "is_boss": True, "boss_type": "killer"},
    "815": {"name": "Vũ Nhất Thể", "title": "Sát Thủ Lưu Tiên Động", "series": 0, "is_boss": True, "boss_type": "killer"},
    "816": {"name": "Diệp Ức Anh", "title": "Sát Thủ Dược Vương Cốc", "series": 2, "is_boss": True, "boss_type": "killer"},
    "817": {"name": "Lạc Nhĩ Kim", "title": "Sát Thủ Dược Vương Cốc", "series": 0, "is_boss": True, "boss_type": "killer"},
    "818": {"name": "Cổ Vô Thường", "title": "Sát Thủ Hoàng Hà Nguyên Đầu", "series": 3, "is_boss": True, "boss_type": "killer"},

    # --- BOSS PHONG LĂNG ĐỘ (phonglangdo.lua) ---
    "725": {"name": "Thủy Tặc Đại Lĩnh", "title": "Đầu Lĩnh Thủy Tặc Phong Lăng Độ", "series": 2, "is_boss": True, "boss_type": "world"},

    # --- BOSS TỐNG KIM CHIẾN TRƯỜNG (STT 1466 - 1474) ---
    "1466": {"name": "Vương Tá (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 0, "is_boss": True, "boss_type": "songjin"},
    "1467": {"name": "Đường Phi Yến (Tống Kim Phó Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 1, "is_boss": True, "boss_type": "songjin"},
    "1468": {"name": "Bạch Doanh Doanh (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 1, "is_boss": True, "boss_type": "songjin"},
    "1469": {"name": "Thanh Tuyệt Sư Thái (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 2, "is_boss": True, "boss_type": "songjin"},
    "1470": {"name": "Chung Linh Tú (Tống Kim Phó Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 2, "is_boss": True, "boss_type": "songjin"},
    "1471": {"name": "Hà Nhân Ngã (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 3, "is_boss": True, "boss_type": "songjin"},
    "1472": {"name": "Đoan Mộc Duệ (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 3, "is_boss": True, "boss_type": "songjin"},
    "1473": {"name": "Thanh Liên Tử (Tống Kim Phó Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 4, "is_boss": True, "boss_type": "songjin"},
    "1474": {"name": "Đạo Thanh Chân Nhân (Tống Kim Đại Tướng)", "title": "Tống Kim Chiến Trường Boss", "series": 4, "is_boss": True, "boss_type": "songjin"},

    # --- BIẾN THÂN BOSS 10 PHÁI (STT 2058 - 2067) ---
    "2058": {"name": "Thiếu Lâm Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Thiếu Lâm", "series": 0, "is_boss": True, "boss_type": "transform"},
    "2059": {"name": "Thiên Vương Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Thiên Vương", "series": 0, "is_boss": True, "boss_type": "transform"},
    "2060": {"name": "Ngũ Độc Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Ngũ Độc", "series": 1, "is_boss": True, "boss_type": "transform"},
    "2061": {"name": "Đường Môn Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Đường Môn", "series": 1, "is_boss": True, "boss_type": "transform"},
    "2062": {"name": "Nga Mi Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Nga Mi", "series": 2, "is_boss": True, "boss_type": "transform"},
    "2063": {"name": "Thúy Yên Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Thúy Yên", "series": 2, "is_boss": True, "boss_type": "transform"},
    "2064": {"name": "Thiên Nhẫn Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Thiên Nhẫn", "series": 3, "is_boss": True, "boss_type": "transform"},
    "2065": {"name": "Cái Bang Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Cái Bang", "series": 3, "is_boss": True, "boss_type": "transform"},
    "2066": {"name": "Võ Đang Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Võ Đang", "series": 4, "is_boss": True, "boss_type": "transform"},
    "2067": {"name": "Côn Lôn Biến Thân Boss", "title": "Biến Thân Tông Sư", "sect": "Côn Lôn", "series": 4, "is_boss": True, "boss_type": "transform"},

    # --- CÁC BOSS HUYỀN THOẠI & SỰ KIỆN KHÁC ---
    "1780": {"name": "Bang Chủ Ác Lang Bang", "title": "Ác Lang Bang Đầu Mục", "series": 0, "is_boss": True, "boss_type": "world"},
    "1832": {"name": "Đường Bất Nhiễm (Đường Môn)", "title": "Tuyệt Đỉnh Ám Khí", "sect": "Đường Môn", "series": 1, "is_boss": True, "boss_type": "gold"},
    "1833": {"name": "Gia Luật Tị Ly (Thiên Nhẫn)", "title": "Thiên Nhẫn Giáo Chủ", "sect": "Thiên Nhẫn", "series": 3, "is_boss": True, "boss_type": "gold"},
    "1835": {"name": "Mạnh Thương Lương (Cái Bang)", "title": "Hàng Long Chưởng", "sect": "Cái Bang", "series": 3, "is_boss": True, "boss_type": "gold"},
    "1845": {"name": "Tuyền Cơ Tử (Côn Lôn)", "title": "Côn Lôn Tông Sư", "sect": "Côn Lôn", "series": 4, "is_boss": True, "boss_type": "gold"},
    "1840": {"name": "Tiêu Nhan", "title": "Tuyệt Sắc Nữ Hiệp", "series": 2, "is_boss": True, "boss_type": "world"},
    "1850": {"name": "Nguyệt Ca Đảo Chủ (Giai đoạn 1)", "title": "Nguyệt Ca Đảo Chủ", "series": 2, "is_boss": True, "boss_type": "world"},
    "1851": {"name": "Nguyệt Ca Đảo Chủ (Giai đoạn 2)", "title": "Nguyệt Ca Đảo Chủ", "series": 2, "is_boss": True, "boss_type": "world"},
    "1852": {"name": "Nguyệt Ca Đảo Chủ (Giai đoạn 3)", "title": "Nguyệt Ca Đảo Chủ", "series": 2, "is_boss": True, "boss_type": "world"},
    "1914": {"name": "Hoàng Kim Thượng Cổ Thần Thụ", "title": "Thần Thụ Nghìn Năm", "series": 1, "is_boss": True, "boss_type": "world"},
    "1957": {"name": "Vô Kiếm Thất", "title": "Kiếm Ma Đệ Nhất Kiếm", "series": 0, "is_boss": True, "boss_type": "world"},
    "1958": {"name": "Triệu Thương Lục", "title": "Kiếm Ma Đệ Nhị Kiếm", "series": 1, "is_boss": True, "boss_type": "world"},
    "1959": {"name": "Lưu Liên Ngũ", "title": "Kiếm Ma Đệ Tam Kiếm", "series": 2, "is_boss": True, "boss_type": "world"},
    "1960": {"name": "Trương Vực Tứ", "title": "Kiếm Ma Đệ Tứ Kiếm", "series": 3, "is_boss": True, "boss_type": "world"},
    "2133": {"name": "Kiếm Tiên Lý Bạch", "title": "Thi Tiên Kiếm Hiệp", "series": 0, "is_boss": True, "boss_type": "world"},
}


def main():
    print(f"Đang nạp file: {MONSTERS_JSON}")
    with open(MONSTERS_JSON, "r", encoding="utf-8") as f:
        monsters = json.load(f)

    updated_count = 0
    for boss_id, meta in BOSS_METADATA.items():
        if boss_id in monsters:
            m = monsters[boss_id]
            old_name = m.get("name", "")
            # Cập nhật thông tin chuẩn
            m["name"] = meta["name"]
            m["is_boss"] = True
            m["boss_type"] = meta.get("boss_type", "gold")
            if "title" in meta:
                m["title"] = meta["title"]
            if "sect" in meta:
                m["sect"] = meta["sect"]
            if "series" in meta:
                m["series"] = meta["series"]
            updated_count += 1
            print(f"  [STT {boss_id}] Đã cập nhật: '{old_name}' -> '{meta['name']}' ({meta.get('boss_type')}, Hệ {meta.get('series')})")
        else:
            print(f"  [STT {boss_id}] Không tìm thấy trong monsters.json!")

    # Ngoài ra, đánh dấu bất kỳ quái nào có res bắt đầu bằng boss và chưa đánh dấu
    auto_boss_count = 0
    for sid, m in monsters.items():
        if sid in BOSS_METADATA:
            continue
        res = m.get("res", "")
        name = m.get("name", "")
        if res.startswith("boss") or "boss" in name.lower():
            m["is_boss"] = True
            if "boss_type" not in m:
                m["boss_type"] = "general"
            auto_boss_count += 1

    print(f"\nTổng cộng đã cập nhật đích danh {updated_count} Boss chính.")
    print(f"Đã tự động gắn cờ is_boss cho {auto_boss_count} boss phụ khác.")

    with open(MONSTERS_JSON, "w", encoding="utf-8") as f:
        json.dump(monsters, f, ensure_ascii=False, indent=1, sort_keys=True)
    print("Ghi thành công vào data/monsters/monsters.json!")


if __name__ == "__main__":
    main()
