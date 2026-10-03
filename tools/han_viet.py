"""Chuyển tên vật phẩm VLTK còn để chữ Hán (vài dòng trong GoldEquip.txt gốc chưa Việt hoá) sang âm HÁN-VIỆT theo
đúng kiểu tên Việt hoá sẵn của game: "梦龙之正红僧帽" -> "Mộng Long Chính Hồng Tăng Mão" (bỏ chữ 之, mỗi chữ 1 âm, viết
hoa đầu âm). Cụm từ cố định (Cà Sa, Bồ Đề, [Tống Kim]...) và vài tên đặc biệt được dịch nguyên cụm trước.
"""

PHRASES = {
    "[宋金]": "[Tống Kim] ",
    "（测试版）": " (Bản thử)",
    "2013中越友谊·": "[Hữu Nghị 2013] ",
}

CHARS = {
    "七": "Thất", "万": "Vạn", "上": "Thượng", "下": "Hạ", "业": "Nghiệp", "两": "Lưỡng", "中": "Trung", "丰": "Phong",
    "乐": "Lạc", "乙": "Ất", "九": "Cửu", "乾": "Càn", "云": "Vân", "仇": "Cừu", "仙": "Tiên", "仪": "Nghi",
    "伏": "Phục", "佛": "Phật", "佩": "Bội", "倾": "Khuynh", "偈": "Kệ", "僧": "Tăng", "光": "Quang", "六": "Lục",
    "兰": "Lan", "共": "Cộng", "典": "Điển", "冠": "Quan", "冥": "Minh", "冰": "Băng", "净": "Tịnh", "凌": "Lăng",
    "凝": "Ngưng", "凤": "Phụng", "凭": "Bằng", "凰": "Hoàng", "刀": "Đao", "利": "Lợi", "剑": "Kiếm", "化": "Hóa",
    "北": "Bắc", "千": "Thiên", "印": "Ấn", "卸": "Tá", "及": "Cập", "友": "Hữu", "双": "Song", "叶": "Diệp",
    "同": "Đồng", "听": "Thính", "命": "Mệnh", "咒": "Chú", "啸": "Khiếu", "善": "Thiện", "嗜": "Thị", "噬": "Phệ",
    "四": "Tứ", "圆": "Viên", "圈": "Khuyên", "在": "Tại", "地": "Địa", "坐": "Tọa", "坠": "Trụy", "城": "Thành",
    "壁": "Bích", "大": "Đại", "天": "Thiên", "太": "Thái", "头": "Đầu", "夺": "Đoạt", "宋": "Tống", "宏": "Hoành",
    "定": "Định", "寒": "Hàn", "寻": "Tầm", "尊": "Tôn", "尸": "Thi", "尾": "Vĩ", "屐": "Lý", "山": "Sơn",
    "岚": "Lam", "岳": "Nhạc", "工": "Công", "巾": "Cân", "布": "Bố", "帽": "Mão", "幻": "Huyễn", "幽": "U",
    "开": "Khai", "弃": "Khí", "弑": "Thí", "归": "Quy", "彩": "Thải", "影": "Ảnh", "往": "Vãng", "御": "Ngự",
    "心": "Tâm", "忘": "Vong", "念": "Niệm", "忾": "Khái", "思": "Tư", "悲": "Bi", "愿": "Nguyện", "慈": "Từ",
    "戈": "Qua", "戏": "Hí", "我": "Ngã", "戒": "Giới", "手": "Thủ", "扣": "Khấu", "护": "Hộ", "披": "Phi",
    "挂": "Quải", "指": "Chỉ", "掠": "Lược", "提": "Đề", "摄": "Nhiếp", "摆": "Bãi", "摘": "Trích", "撼": "Hám",
    "擒": "Cầm", "敌": "Địch", "斗": "Đẩu", "断": "Đoạn", "无": "Vô", "日": "Nhật", "明": "Minh", "星": "Tinh",
    "映": "Ánh", "晓": "Hiểu", "晶": "Tinh", "暗": "Ám", "月": "Nguyệt", "木": "Mộc", "束": "Thúc", "极": "Cực",
    "枢": "Xu", "枯": "Khô", "栖": "Thê", "桐": "Đồng", "梦": "Mộng", "梧": "Ngô", "森": "Sâm", "楼": "Lâu",
    "正": "Chính", "步": "Bộ", "殇": "Thương", "毒": "Độc", "气": "Khí", "水": "Thủy", "汗": "Hãn", "沐": "Mộc",
    "沙": "Sa", "泪": "Lệ", "测": "Trắc", "浑": "Hồn", "浮": "Phù", "海": "Hải", "涯": "Nhai", "渡": "Độ",
    "游": "Du", "溶": "Dung", "滴": "Trích", "火": "Hỏa", "灭": "Diệt", "灵": "Linh", "灼": "Chước", "炎": "Viêm",
    "炼": "Luyện", "炽": "Sí", "烟": "Yên", "焚": "Phần", "焰": "Diễm", "煞": "Sát", "照": "Chiếu", "爪": "Trảo",
    "版": "Bản", "狮": "Sư", "玄": "Huyền", "玉": "Ngọc", "王": "Vương", "环": "Hoàn", "珠": "Châu", "琼": "Quỳnh",
    "生": "Sinh", "甲": "Giáp", "留": "Lưu", "登": "Đăng", "白": "Bạch", "百": "Bách", "盔": "Khôi", "盘": "Bàn",
    "相": "Tướng", "睛": "Tình", "破": "Phá", "碧": "Bích", "神": "Thần", "禅": "Thiền", "秋": "Thu", "穹": "Khung",
    "空": "Không", "符": "Phù", "粹": "Túy", "紫": "Tử", "絮": "Nhứ", "繁": "Phồn", "纯": "Thuần", "纱": "Sa",
    "纵": "Túng", "织": "Chức", "结": "Kết", "绣": "Tú", "继": "Kế", "缈": "Miểu", "缎": "Đoạn", "缠": "Triền",
    "缥": "Phiêu", "罡": "Cương", "羊": "Dương", "羽": "Vũ", "胆": "Đảm", "胧": "Lung", "腕": "Uyển", "舍": "Xá",
    "般": "Ban", "花": "Hoa", "苍": "Thương", "若": "Nhược", "草": "Thảo", "荒": "Hoang", "菩": "Bồ", "落": "Lạc",
    "蕴": "Uẩn", "藏": "Tàng", "藤": "Đằng", "虚": "Hư", "蝶": "Điệp", "血": "Huyết", "衣": "Y", "袈": "Cà",
    "袍": "Bào", "袖": "Tụ", "裟": "Sa", "裳": "Thường", "试": "Thí", "语": "Ngữ", "谊": "Nghị", "象": "Tượng",
    "赤": "Xích", "越": "Việt", "踏": "Đạp", "踪": "Tung", "轮": "Luân", "软": "Nhuyễn", "辰": "Thần", "逍": "Tiêu",
    "逐": "Trục", "通": "Thông", "道": "Đạo", "遥": "Dao", "邪": "Tà", "金": "Kim", "铠": "Khải", "链": "Liên",
    "锐": "Duệ", "镇": "Trấn", "镜": "Kính", "间": "Gian", "阳": "Dương", "降": "Hàng", "雨": "Vũ", "雪": "Tuyết",
    "雷": "Lôi", "霄": "Tiêu", "霜": "Sương", "霞": "Hà", "霸": "Bá", "青": "Thanh", "静": "Tĩnh", "靴": "Ngoa",
    "韵": "Vận", "项": "Hạng", "顿": "Đốn", "风": "Phong", "飞": "Phi", "香": "Hương", "驱": "Khu", "驹": "Câu",
    "驼": "Đà", "骨": "Cốt", "鬼": "Quỷ", "魂": "Hồn", "魅": "Mị", "魇": "Yểm", "魔": "Ma", "黄": "Hoàng",
    "龙": "Long",
}


def to_han_viet(name: str) -> str:
    """Tên chữ Hán -> Hán-Việt. Chữ chưa có trong bảng giữ nguyên (dễ phát hiện để bổ sung)."""
    for zh, vi in PHRASES.items():
        name = name.replace(zh, "\x00" + vi + "\x00")
    out, word = [], []
    for part in name.split("\x00"):
        if part in PHRASES.values():
            out.append(part)
            continue
        syllables = [CHARS.get(ch, ch) for ch in part if ch != "之"]
        out.append(" ".join(syllables))
    return "".join(out).replace("  ", " ").strip()
