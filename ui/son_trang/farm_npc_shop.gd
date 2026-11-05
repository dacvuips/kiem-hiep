extends CanvasLayer
class_name FarmNPCShop
## Cửa sổ Giao Diện Cửa Hàng 4 NPC Sơn Trang Nguyệt Ca Đảo
## - NPC Chăn Nuôi (195/192) - Trương Bá
## - NPC Trồng Trọt (191/186) - Thần Nông Tiên Sinh
## - NPC Cá Nước Ngọt (180/185) - Khê Hồ Ngư Nương
## - NPC Đánh Bắt & Nuôi Cá Biển (196/197) - Hải Ngư Thuyền Trưởng

const ICON_PATH_PREFIX := "res://assets/items/icons/"

## Danh mục hàng hóa chuẩn xác với icon cục bộ trong source
const SHOP_CATALOG := {
	"livestock": {
		"title": "🏪 [THƯƠNG NHÂN ĐỘNG VẬT & LOÀI CHIM] TRƯƠNG BÁ",
		"location": "Tọa độ 195/192 (Khu Vật Nuôi Sơn Trang)",
		"greeting": "🐾 \"Đại hiệp cần mua giống vật nuôi nào? Ở đây chuyên cung ứng đủ các loại gia súc, dã thú và chim trời quý hiếm! (Lưu ý: Thú nuôi chỉ ăn nông sản tự trồng hoặc cá tự câu/nuôi thu hoạch)\"",
		"theme_color": Color(0.95, 0.75, 0.25),
		"items": [
			# --- CỰ THÚ SA TRƯỜNG & LOÀI VOI (MẮC NHẤT X10 LẦN: 2500 LƯỢNG) ---
			{
				"id": "animal_elephant_hoang_ha",
				"animal_id": "elephant_hoang_ha",
				"name": "Voi Hoàng Hà Cổ Tượng",
				"monster_res": "ani024",
				"icon": "baihuling.png",
				"price_gold": 2500,
				"price_xu": 0,
				"desc": "Cổ tượng Hoàng Hà uy dũng sa trường, thân hình đồ sộ tựa non cao, uy trấn sơn môn (giá mắc nhất x10 lần).",
				"category_tag": "Thần Thú Cự Đại",
				"harvest_prod": "Ngà Voi Hoàng Hà Quý",
				"grow_time": 600,
				"gold_reward": 800
			},
			{
				"id": "animal_elephant_giant",
				"animal_id": "elephant_giant",
				"name": "Bạch Tượng Thần Thú",
				"monster_res": "ani021",
				"icon": "baihuling.png",
				"price_gold": 2500,
				"price_xu": 0,
				"desc": "Đại tượng khổng lồ ngàn năm sức mạnh bạt sơn cái thế, bảo vệ gia trang vững như bàn thạch (giá mắc nhất x10 lần).",
				"category_tag": "Thần Thú Cự Đại",
				"harvest_prod": "Bạch Ngọc Tượng Nha",
				"grow_time": 600,
				"gold_reward": 800
			},

			# --- LOÀI GẤU (BẠO HÙNG SƠN LÂM) ---
			{
				"id": "animal_bear_brown",
				"animal_id": "bear_brown",
				"name": "Bạo Hùng Gấu Nâu",
				"monster_res": "ani025",
				"icon": "zhurou.png",
				"price_gold": 220,
				"price_xu": 0,
				"desc": "Bạo hùng dũng mãnh mình đồng da sắt, hộ vệ chuồng trại và cho Mật Gấu Rừng đại bổ.",
				"category_tag": "Mãnh Thú Sơn Lâm",
				"harvest_prod": "Mật Gấu Rừng Đại Bổ",
				"grow_time": 360,
				"gold_reward": 260
			},
			{
				"id": "animal_bear_black",
				"animal_id": "bear_black",
				"name": "Hắc Hùng Gấu Đen",
				"monster_res": "ani026",
				"icon": "zhurou.png",
				"price_gold": 200,
				"price_xu": 0,
				"desc": "Hắc hùng phương bắc thiện chiến, cung cấp Da Gấu Đen dày dặn chống rét.",
				"category_tag": "Mãnh Thú Sơn Lâm",
				"harvest_prod": "Da Hắc Hùng Thượng Hạng",
				"grow_time": 330,
				"gold_reward": 240
			},
			{
				"id": "animal_bear_raccoon",
				"animal_id": "bear_raccoon",
				"name": "Hoán Hùng Linh Thú",
				"monster_res": "ani051",
				"icon": "huasheng.png",
				"price_gold": 120,
				"price_xu": 0,
				"desc": "Gấu mèo hoạt bát tinh khôn, bắt chước người trông coi kho bãi và thu Lông Hoán Hùng mượt mà.",
				"category_tag": "Linh Thú Tinh Nghịch",
				"harvest_prod": "Lông Hoán Hùng Mềm",
				"grow_time": 180,
				"gold_reward": 150
			},

			# --- LOÀI HỔ & BÁO (CHÚA TỂ RỪNG XANH) ---
			{
				"id": "animal_tiger",
				"animal_id": "tiger",
				"name": "Bạch Hổ Chúa Sơn Lâm",
				"monster_res": "ani001",
				"icon": "baihuling.png",
				"price_gold": 250,
				"price_xu": 0,
				"desc": "Mãnh thú hộ vệ trang nghiêm (5 phút), uy trấn sơn môn, thu Oai Lực Sơn Lâm.",
				"category_tag": "Thần Thú Hộ Vệ",
				"harvest_prod": "Oai Lực Sơn Lâm",
				"grow_time": 300,
				"gold_reward": 300
			},
			{
				"id": "animal_tiger_blood",
				"animal_id": "tiger_blood",
				"name": "Sát Huyết Mãnh Hổ",
				"monster_res": "ani002",
				"icon": "baihuling.png",
				"price_gold": 230,
				"price_xu": 0,
				"desc": "Hổ vằn Hoa Nam thiện chiến hung hãn, trấn giữ sơn cốc và thu Hổ Cốt Thần Dược.",
				"category_tag": "Mãnh Thú Thượng Cổ",
				"harvest_prod": "Hổ Cốt Thần Dược",
				"grow_time": 300,
				"gold_reward": 270
			},
			{
				"id": "animal_tiger_snow",
				"animal_id": "tiger_snow",
				"name": "Bạch Hổ Tuyết Sơn",
				"monster_res": "ani003",
				"icon": "baihuling.png",
				"price_gold": 250,
				"price_xu": 0,
				"desc": "Bạch hổ ngàn năm trên đỉnh Tuyết Sơn, toàn thân tỏa hàn khí băng giá thanh khiết.",
				"category_tag": "Thần Thú Băng Tuyết",
				"harvest_prod": "Băng Phách Bạch Hổ",
				"grow_time": 320,
				"gold_reward": 300
			},
			{
				"id": "animal_leopard_gold",
				"animal_id": "leopard_gold",
				"name": "Kim Tiền Báo Hoa Mai",
				"monster_res": "ani005",
				"icon": "baihuling.png",
				"price_gold": 170,
				"price_xu": 0,
				"desc": "Báo gấm hoa mai tốc độ như tia chớp, tuần tra sơn môn chớp nhoáng bảo vệ thú con.",
				"category_tag": "Mãnh Thú Thần Tốc",
				"harvest_prod": "Da Báo Hoa Mai",
				"grow_time": 210,
				"gold_reward": 210
			},
			{
				"id": "animal_leopard_snow",
				"animal_id": "leopard_snow",
				"name": "Tuyết Báo Vương",
				"monster_res": "ani006",
				"icon": "baihuling.png",
				"price_gold": 190,
				"price_xu": 0,
				"desc": "Chúa tể loài báo tuyết bắc cực băng giá, thoắt ẩn thoắt hiện trong gió tuyết.",
				"category_tag": "Linh Báo Băng Giá",
				"harvest_prod": "Lông Tuyết Báo Quý",
				"grow_time": 240,
				"gold_reward": 230
			},

			# --- LOÀI SÓI (DÃ THÚ SĂN MỒI TRUNG THÀNH) ---
			{
				"id": "animal_wolf",
				"animal_id": "wolf",
				"name": "Hồng Lang Sói Đỏ",
				"monster_res": "ani010",
				"icon": "canglangling.png",
				"price_gold": 110,
				"price_xu": 0,
				"desc": "Dã thú trung thành tuyệt đối (3 phút), tuần tra trang trại, thu Nanh Sói Dũng Sĩ.",
				"category_tag": "Dã Thú Săn Mồi",
				"harvest_prod": "Nanh Sói Dũng Sĩ",
				"grow_time": 190,
				"gold_reward": 140
			},
			{
				"id": "animal_wolf_gray",
				"animal_id": "wolf_gray",
				"name": "Hôi Lang Sói Xám",
				"monster_res": "ani009",
				"icon": "canglangling.png",
				"price_gold": 95,
				"price_xu": 0,
				"desc": "Sói xám đồng hoang tinh quái bền bỉ, trung dũng canh giữ đàn gia súc khỏi đạo tặc.",
				"category_tag": "Dã Thú Thảo Nguyên",
				"harvest_prod": "Da Sói Xám Bền",
				"grow_time": 170,
				"gold_reward": 125
			},
			{
				"id": "animal_wolf_green",
				"animal_id": "wolf_green",
				"name": "Thanh Lang Ác Thú",
				"monster_res": "ani011",
				"icon": "canglangling.png",
				"price_gold": 115,
				"price_xu": 0,
				"desc": "Sói xanh mắt sáng rực trong bóng đêm, hộ vệ chuồng trại trước kẻ gian.",
				"category_tag": "Dã Thú Săn Mồi",
				"harvest_prod": "Nanh Thanh Lang",
				"grow_time": 180,
				"gold_reward": 145
			},
			{
				"id": "animal_wolf_snow",
				"animal_id": "wolf_snow",
				"name": "Bạch Lang Tuyết Vực",
				"monster_res": "ani012",
				"icon": "canglangling.png",
				"price_gold": 140,
				"price_xu": 0,
				"desc": "Sói trắng bắc cực chịu giá rét phi thường, tiếng hú vang vọng sơn cốc.",
				"category_tag": "Linh Lang Tuyết Sơn",
				"harvest_prod": "Bộ Lông Sói Tuyết",
				"grow_time": 200,
				"gold_reward": 175
			},

			# --- LOÀI CÁO / HỒ LY ---
			{
				"id": "animal_fox",
				"animal_id": "fox",
				"name": "Bạch Cáo Tuyết Hồ",
				"monster_res": "ani013",
				"icon": "heidiaoxin.png",
				"price_gold": 160,
				"price_xu": 0,
				"desc": "Linh thú thông tuệ (3.5 phút), bộ lông trắng mướt mềm mịn như mây tuyết.",
				"category_tag": "Linh Thú Quý",
				"harvest_prod": "Lông Tuyết Hồ",
				"grow_time": 210,
				"gold_reward": 200
			},
			{
				"id": "animal_fox_fire",
				"animal_id": "fox_fire",
				"name": "Cửu Vĩ Hỏa Hồ",
				"monster_res": "ani015",
				"icon": "heidiaoxin.png",
				"price_gold": 210,
				"price_xu": 0,
				"desc": "Hồ ly lửa đỏ mang linh khí đất trời, đem lại may mắn tài lộc cho sơn trang.",
				"category_tag": "Linh Thú Thần Bí",
				"harvest_prod": "Hỏa Linh Hồ Ngọc",
				"grow_time": 270,
				"gold_reward": 260
			},

			# --- GIA SÚC & HƯƠU NAI ---
			{
				"id": "animal_pig",
				"animal_id": "pig",
				"name": "Heo Trắng Giống",
				"monster_res": "ani063",
				"icon": "zhurou.png",
				"price_gold": 40,
				"price_xu": 0,
				"desc": "Gia súc dễ nuôi mau lớn (2 phút), thu hoạch Thịt Heo Sạch thơm ngon.",
				"category_tag": "Gia Súc",
				"harvest_prod": "Thịt Heo Sạch",
				"grow_time": 120,
				"gold_reward": 60
			},
			{
				"id": "animal_boar",
				"animal_id": "boar",
				"name": "Heo Rừng Dũng Mãnh",
				"monster_res": "ani018",
				"icon": "zhurou.png",
				"price_gold": 60,
				"price_xu": 0,
				"desc": "Dã thú hoang dã sức đề kháng cao (2.5 phút), cho Thịt Heo Rừng săn chắc.",
				"category_tag": "Dã Thú",
				"harvest_prod": "Thịt Heo Rừng",
				"grow_time": 150,
				"gold_reward": 80
			},
			{
				"id": "animal_buffalo",
				"animal_id": "buffalo",
				"name": "Trâu Cày Sơn Trang",
				"monster_res": "ani029",
				"icon": "mailk.png",
				"price_gold": 70,
				"price_xu": 0,
				"desc": "Trâu cày kéo khỏe khoắn (3 phút), sản xuất dòng Sữa Trâu Thơm béo ngậy.",
				"category_tag": "Gia Súc Lớn",
				"harvest_prod": "Sữa Trâu Thơm",
				"grow_time": 180,
				"gold_reward": 95
			},
			{
				"id": "animal_deer",
				"animal_id": "deer",
				"name": "Hươu Sao Đồng Cỏ",
				"monster_res": "ani061",
				"icon": "bainianqixingcao.png",
				"price_gold": 100,
				"price_xu": 0,
				"desc": "Động vật quý hiếm (4 phút), thu hoạch Nhung Hươu Quý đại bổ nguyên khí.",
				"category_tag": "Động Vật Quý",
				"harvest_prod": "Nhung Hươu Quý",
				"grow_time": 240,
				"gold_reward": 130
			},
			{
				"id": "animal_deer_fragrant",
				"animal_id": "deer_fragrant",
				"name": "Bách Hương Thần Lộc",
				"monster_res": "ani069",
				"icon": "bainianqixingcao.png",
				"price_gold": 150,
				"price_xu": 0,
				"desc": "Hươu xạ hương tỏa mùi thơm thanh tao ngàn dặm, tinh chất quý để luyện đan dược.",
				"category_tag": "Linh Thú Quý Hiếm",
				"harvest_prod": "Túi Xạ Hương Quý",
				"grow_time": 250,
				"gold_reward": 190
			},

			# --- LOÀI MÈO & NHÍM ---
			{
				"id": "animal_cat",
				"animal_id": "cat",
				"name": "Linh Miêu Gấm",
				"monster_res": "ani052",
				"icon": "yadan.png",
				"price_gold": 65,
				"price_xu": 0,
				"desc": "Mèo rừng thông minh (2 phút), bắt chuột giữ kho lương, thu Lông Mèo Gấm.",
				"category_tag": "Thú Cưng Giữ Kho",
				"harvest_prod": "Lông Mèo Gấm",
				"grow_time": 130,
				"gold_reward": 85
			},
			{
				"id": "animal_cat_gold",
				"animal_id": "cat_gold",
				"name": "Kim Miêu Hoàng Gia",
				"monster_res": "ani049",
				"icon": "yadan.png",
				"price_gold": 80,
				"price_xu": 0,
				"desc": "Mèo vàng lông kim óng ánh, bắt chuột giữ thóc gạo sơn trang nguyên vẹn.",
				"category_tag": "Linh Miêu Quý Tộc",
				"harvest_prod": "Lông Kim Miêu",
				"grow_time": 140,
				"gold_reward": 105
			},
			{
				"id": "animal_cat_gem",
				"animal_id": "cat_gem",
				"name": "Xá Lị Linh Miêu",
				"monster_res": "ani050",
				"icon": "yadan.png",
				"price_gold": 75,
				"price_xu": 0,
				"desc": "Mèo hai màu mắt ngọc linh thông, trừ tà và báo hiệu điềm lành cho gia trang.",
				"category_tag": "Linh Miêu Trấn Trạch",
				"harvest_prod": "Ngọc Mắt Mèo",
				"grow_time": 135,
				"gold_reward": 100
			},
			{
				"id": "animal_hedgehog",
				"animal_id": "hedgehog",
				"name": "Nhím Gai Rừng",
				"monster_res": "ani019",
				"icon": "songzhen.png",
				"price_gold": 45,
				"price_xu": 0,
				"desc": "Động vật nhỏ hiền lành dễ thương (1.6 phút), thu hoạch Gai Nhím Quý.",
				"category_tag": "Động Vật Nhỏ",
				"harvest_prod": "Gai Nhím Rừng",
				"grow_time": 100,
				"gold_reward": 65
			},

			# --- LOÀI KHỈ & CHÓ RỪNG ---
			{
				"id": "animal_monkey",
				"animal_id": "monkey",
				"name": "Khỉ Xám Rừng Trúc",
				"monster_res": "ani054",
				"icon": "huasheng.png",
				"price_gold": 55,
				"price_xu": 0,
				"desc": "Linh trưởng lanh lợi tinh nghịch (1.8 phút), phụ giúp thu gom Trái Cây Rừng.",
				"category_tag": "Linh Trưởng",
				"harvest_prod": "Trái Cây Rừng",
				"grow_time": 110,
				"gold_reward": 75
			},
			{
				"id": "animal_monkey_tibetan",
				"animal_id": "monkey_tibetan",
				"name": "Tàng Vực Tuyết Hầu",
				"monster_res": "ani053",
				"icon": "huasheng.png",
				"price_gold": 70,
				"price_xu": 0,
				"desc": "Khỉ tuyết cao nguyên thuần hậu, chuyên hái dược thảo vách đá cheo leo.",
				"category_tag": "Linh Trưởng Núi Cao",
				"harvest_prod": "Tuyết Sơn Thảo Quả",
				"grow_time": 130,
				"gold_reward": 95
			},
			{
				"id": "animal_monkey_black",
				"animal_id": "monkey_black",
				"name": "Hắc Diệp Thần Hầu",
				"monster_res": "ani055",
				"icon": "huasheng.png",
				"price_gold": 85,
				"price_xu": 0,
				"desc": "Vượn đen rừng sâu trèo đèo lội suối, canh gác các lối vào trang trại.",
				"category_tag": "Linh Trưởng Rừng Sâu",
				"harvest_prod": "Quả Rừng Hắc Diệp",
				"grow_time": 150,
				"gold_reward": 115
			},
			{
				"id": "animal_monkey_golden",
				"animal_id": "monkey_golden",
				"name": "Kim Tơ Hoàng Hầu",
				"monster_res": "ani056",
				"icon": "huasheng.png",
				"price_gold": 130,
				"price_xu": 0,
				"desc": "Khỉ lông vàng quý hiếm thông minh tuyệt đỉnh, hiểu tiếng người như tri kỷ.",
				"category_tag": "Linh Trưởng Quý Tộc",
				"harvest_prod": "Lông Tơ Vàng Kim",
				"grow_time": 180,
				"gold_reward": 170
			},
			{
				"id": "animal_jackal",
				"animal_id": "jackal",
				"name": "Sài Lang Hoang Dã",
				"monster_res": "ani058",
				"icon": "canglangling.png",
				"price_gold": 90,
				"price_xu": 0,
				"desc": "Chó rừng sài lang dẻo dai trung dũng, tuần tra ranh giới bảo vệ đàn thú con.",
				"category_tag": "Dã Thú Canh Gác",
				"harvest_prod": "Vuốt Sài Lang",
				"grow_time": 160,
				"gold_reward": 120
			},

			# --- LOÀI CHIM SĂN MỒI & LOÀI DƠI ---
			{
				"id": "animal_eagle",
				"animal_id": "eagle",
				"name": "Đại Bàng Thứu Thần",
				"monster_res": "ani042",
				"icon": "bamboo.png",
				"price_gold": 130,
				"price_xu": 0,
				"desc": "Loài chim săn mồi chúa tể bầu trời (3.3 phút), thu hoạch Lông Vũ Đại Bàng quý.",
				"category_tag": "Loài Chim Săn Mồi",
				"harvest_prod": "Lông Vũ Đại Bàng",
				"grow_time": 200,
				"gold_reward": 170
			},
			{
				"id": "animal_eagle_gold",
				"animal_id": "eagle_gold",
				"name": "Kim Điêu Thiên Ưng",
				"monster_res": "ani041",
				"icon": "bamboo.png",
				"price_gold": 150,
				"price_xu": 0,
				"desc": "Đại điêu vàng sải cánh ngút trời, trinh sát tuần tra từ tầng mây cao nhất.",
				"category_tag": "Chim Săn Mồi Quý",
				"harvest_prod": "Lông Kim Điêu",
				"grow_time": 220,
				"gold_reward": 195
			},
			{
				"id": "animal_vulture",
				"animal_id": "vulture",
				"name": "Chim Kền Kền Núi",
				"monster_res": "ani043",
				"icon": "bamboo.png",
				"price_gold": 85,
				"price_xu": 0,
				"desc": "Loài chim trời kiên cường (2.6 phút), hộ vệ trang trại và thu Lông Chim Ưng.",
				"category_tag": "Loài Chim Trời",
				"harvest_prod": "Lông Chim Ưng",
				"grow_time": 160,
				"gold_reward": 115
			},
			{
				"id": "animal_bat_lord",
				"animal_id": "bat_lord",
				"name": "Hắc Dạ Dơi Chúa",
				"monster_res": "ani045",
				"icon": "bamboo.png",
				"price_gold": 100,
				"price_xu": 0,
				"desc": "Chúa tể loài dơi đêm, lượn lờ trong bóng tối bảo vệ trang trại lúc nửa đêm.",
				"category_tag": "Dạ Hành Thú",
				"harvest_prod": "Dạ Minh Cánh Dơi",
				"grow_time": 160,
				"gold_reward": 130
			},
			{
				"id": "animal_bat_red",
				"animal_id": "bat_red",
				"name": "Huyết Dạ Dơi Đỏ",
				"monster_res": "ani046",
				"icon": "bamboo.png",
				"price_gold": 110,
				"price_xu": 0,
				"desc": "Dơi chúa đỏ rực huyền bí, đôi mắt đỏ như ruby chiếu sáng đường đêm.",
				"category_tag": "Dạ Hành Thú",
				"harvest_prod": "Xích Dạ Dơi Thạch",
				"grow_time": 170,
				"gold_reward": 145
			},
			{
				"id": "animal_bat_cave",
				"animal_id": "bat_cave",
				"name": "Thâm Lâm Dơi Dong",
				"monster_res": "ani047",
				"icon": "bamboo.png",
				"price_gold": 70,
				"price_xu": 0,
				"desc": "Dơi dong rừng rậm hiền lành, bắt sâu bọ côn trùng hại mùa màng ruộng vườn.",
				"category_tag": "Dạ Hành Thú",
				"harvest_prod": "Bột Dạ Quang",
				"grow_time": 120,
				"gold_reward": 95
			},
			{
				"id": "animal_bat_blood",
				"animal_id": "bat_blood",
				"name": "Huyết Dơi Hút Máu",
				"monster_res": "ani048",
				"icon": "bamboo.png",
				"price_gold": 85,
				"price_xu": 0,
				"desc": "Dơi cánh nhung nhanh nhẹn, khứu giác tinh nhạy phát hiện kẻ lạ xâm nhập.",
				"category_tag": "Dạ Hành Thú",
				"harvest_prod": "Nhung Cánh Dơi",
				"grow_time": 140,
				"gold_reward": 110
			},

			# --- BÒ SÁT & CỰ THÚ DỊ CHỦNG ---
			{
				"id": "animal_crocodile",
				"animal_id": "crocodile",
				"name": "Cá Sấu Cự Ngạc",
				"monster_res": "ani033",
				"icon": "caoyu.png",
				"price_gold": 180,
				"price_xu": 0,
				"desc": "Cá sấu đầm lầy da vảy cứng chắc như giáp sắt, trấn giữ ao đầm.",
				"category_tag": "Thủy Ngạc Cự Thú",
				"harvest_prod": "Da Cá Sấu Quý",
				"grow_time": 280,
				"gold_reward": 230
			},
			{
				"id": "animal_lizard",
				"animal_id": "lizard",
				"name": "Hỏa Diễm Thằn Lằn Đỏ",
				"monster_res": "ani036",
				"icon": "huasheng.png",
				"price_gold": 90,
				"price_xu": 0,
				"desc": "Thằn lằn vảy đỏ núi đá hấp thu nhiệt độ sưởi ấm chuồng trại mùa đông.",
				"category_tag": "Dị Chủng Bò Sát",
				"harvest_prod": "Vảy Thằn Lằn Đỏ",
				"grow_time": 150,
				"gold_reward": 120
			},
			{
				"id": "animal_snake_cobra",
				"animal_id": "snake_cobra",
				"name": "Nhãn Kính Mãng Xà",
				"monster_res": "ani037",
				"icon": "yuer.png",
				"price_gold": 135,
				"price_xu": 0,
				"desc": "Hổ mang chúa mắt kính oai vệ, thu nọc rắn chế độc dược và huyết thanh bổ.",
				"category_tag": "Linh Xà Độc Vật",
				"harvest_prod": "Nọc Rắn Mắt Kính Quý",
				"grow_time": 200,
				"gold_reward": 175
			},
			{
				"id": "animal_snake_green",
				"animal_id": "snake_green",
				"name": "Bích Luyện Thanh Xà",
				"monster_res": "ani038",
				"icon": "yuer.png",
				"price_gold": 95,
				"price_xu": 0,
				"desc": "Rắn xanh thanh nhã bò trườn bờ tre, đuổi chuột giữ kho thóc an lành.",
				"category_tag": "Linh Xà Dược Liệu",
				"harvest_prod": "Mật Thanh Xà",
				"grow_time": 160,
				"gold_reward": 125
			},
			{
				"id": "animal_snake_golden",
				"animal_id": "snake_golden",
				"name": "Kim Hoàn Mãng Xà",
				"monster_res": "ani039",
				"icon": "yuer.png",
				"price_gold": 120,
				"price_xu": 0,
				"desc": "Trăn gấm khoang vàng óng ánh, biểu tượng của sự trù phú và hưng thịnh.",
				"category_tag": "Linh Xà Hoàng Kim",
				"harvest_prod": "Da Trăn Gấm Vàng",
				"grow_time": 190,
				"gold_reward": 155
			},
			{
				"id": "animal_snake_fire",
				"animal_id": "snake_fire",
				"name": "Xích Luyện Hỏa Xà",
				"monster_res": "ani040",
				"icon": "yuer.png",
				"price_gold": 110,
				"price_xu": 0,
				"desc": "Rắn đỏ lửa thân mình dẻo dai, tỏa hơi ấm khắp sơn cốc mùa băng giá.",
				"category_tag": "Linh Xà Hỏa Linh",
				"harvest_prod": "Xích Luyện Xà Châu",
				"grow_time": 180,
				"gold_reward": 145
			},
			{
				"id": "animal_toad_gold",
				"animal_id": "toad_gold",
				"name": "Kim Thiềm Thần Cóc",
				"monster_res": "ani060",
				"icon": "yadan.png",
				"price_gold": 165,
				"price_xu": 0,
				"desc": "Cóc vàng chiêu tài ngậm tiền, mang may mắn phát đạt bội thu cho sơn trang.",
				"category_tag": "Thần Thú Chiêu Tài",
				"harvest_prod": "Thiềm Thừ Kim Châu",
				"grow_time": 220,
				"gold_reward": 215
			},
			{
				"id": "animal_yeti_snow",
				"animal_id": "yeti_snow",
				"name": "Bắc Vực Tuyết Quái",
				"monster_res": "ani059",
				"icon": "baihuling.png",
				"price_gold": 230,
				"price_xu": 0,
				"desc": "Dị thú khổng lồ lông trắng vùng bắc cực, sức mạnh kinh thiên động địa bảo vệ gia trang.",
				"category_tag": "Dị Thú Cực Bắc",
				"harvest_prod": "Tuyết Băng Cốt Quý",
				"grow_time": 320,
				"gold_reward": 280
			},
			{
				"id": "animal_scorpion",
				"animal_id": "scorpion",
				"name": "Thiết Giáp Bọ Cạp",
				"monster_res": "ani065",
				"icon": "songzhen.png",
				"price_gold": 85,
				"price_xu": 0,
				"desc": "Bọ cạp vỏ đen sắt cứng cáp, nọc đuôi chế tạo linh đơn hộ thể.",
				"category_tag": "Ngũ Độc Linh Trùng",
				"harvest_prod": "Nọc Bọ Cạp Thiết Giáp",
				"grow_time": 140,
				"gold_reward": 115
			},
			{
				"id": "animal_spider",
				"animal_id": "spider",
				"name": "Ngũ Thái Thần Thù",
				"monster_res": "ani066",
				"icon": "yadan.png",
				"price_gold": 95,
				"price_xu": 0,
				"desc": "Nhện năm màu dệt tơ ngũ sắc lấp lánh bền chắc dẻo dai hơn thép.",
				"category_tag": "Ngũ Độc Linh Trùng",
				"harvest_prod": "Tơ Nhện Ngũ Sắc",
				"grow_time": 150,
				"gold_reward": 125
			},
			{
				"id": "animal_centipede",
				"animal_id": "centipede",
				"name": "Thiên Tố Cự Ngô Công",
				"monster_res": "ani067",
				"icon": "songzhen.png",
				"price_gold": 90,
				"price_xu": 0,
				"desc": "Rết khổng lồ nhiều chân bò thoăn thoắt, thảo dược quý hỗ trợ luyện công.",
				"category_tag": "Ngũ Độc Linh Trùng",
				"harvest_prod": "Cự Ngô Công Thần Dược",
				"grow_time": 145,
				"gold_reward": 120
			}
		]
	},
	"agriculture": {
		"title": "🏪 [ĐIỀN CHỦ TRỒNG TRỌT] THẦN NÔNG TIÊN SINH",
		"location": "Tọa độ 191/186 (Thềm Đá Ruộng Vườn)",
		"greeting": "🌱 \"Thiên thời địa lợi nhân hòa! Lão phu lưu giữ các loại kỳ hoa dị thảo và hạt giống trù phú, chúc đại hiệp mùa màng bội thu!\"",
		"theme_color": Color(0.40, 0.90, 0.45),
		"items": [
			{
				"id": "rice",
				"name": "Hạt Giống Lúa Nước",
				"icon": "seed_lucky.png",
				"price_gold": 10,
				"price_xu": 0,
				"desc": "Giống lúa hạt tròn vàng óng, thời gian sinh trưởng 1 phút, năng suất ổn định.",
				"supply_key": "rice"
			},
			{
				"id": "cabbage",
				"name": "Hạt Giống Bắp Cải",
				"icon": "bainianqixingcao.png",
				"price_gold": 15,
				"price_xu": 0,
				"desc": "Rau bắp cải xanh tươi giòn ngọt, thu hoạch sau 1.5 phút.",
				"supply_key": "cabbage"
			},
			{
				"id": "tomato",
				"name": "Hạt Giống Cà Chua",
				"icon": "seed_normal.png",
				"price_gold": 25,
				"price_xu": 0,
				"desc": "Quả mọng đỏ tươi nhiều vitamin, thời gian sinh trưởng 2 phút.",
				"supply_key": "tomato"
			},
			{
				"id": "potato",
				"name": "Hạt Giống Khoai Tây",
				"icon": "hongshu.png",
				"price_gold": 40,
				"price_xu": 0,
				"desc": "Củ to nhiều bột, bán lấy ngân lượng cao, thời gian lớn 2.5 phút.",
				"supply_key": "potato"
			},
			{
				"id": "watermelon",
				"name": "Hạt Giống Dưa Hấu",
				"icon": "seed_rose.png",
				"price_gold": 60,
				"price_xu": 0,
				"desc": "Dưa hấu vỏ mỏng ruột đỏ ngọt mát, mùa thu hoạch 3 phút.",
				"supply_key": "watermelon"
			},
			{
				"id": "herb",
				"name": "Hạt Giống Thảo Dược Quý",
				"icon": "seed_gold.png",
				"price_gold": 120,
				"price_xu": 0,
				"desc": "Thần thảo ngàn năm chuyên luyện linh đơn thần dược, thời gian lớn 5 phút.",
				"supply_key": "herb"
			},
			{
				"id": "fertilizer",
				"name": "Bao Phân Bón Vi Sinh",
				"icon": "feiliaodai.png",
				"price_gold": 30,
				"price_xu": 0,
				"desc": "Phân bón hữu cơ rải lên luống đất, rút ngắn 30% thời gian lớn của cây trồng.",
				"supply_key": "fertilizer"
			},
			{
				"id": "tool_watercan",
				"name": "Bình Tưới Nước Đồng",
				"icon": "shuitong.png",
				"price_gold": 40,
				"price_xu": 0,
				"desc": "Bình tưới giữ ẩm đất ruộng, tăng 20% tốc độ lớn cho cây.",
				"is_tool": true,
				"tool_key": "watering_can"
			},
			{
				"id": "tool_hoe",
				"name": "Cuốc Thép Khai Hoang",
				"icon": "chan.png",
				"price_gold": 50,
				"price_xu": 0,
				"desc": "Cuốc thép sắc bén dùng khai hoang mở rộng và nâng cấp luống đất trồng màu mỡ.",
				"is_tool": true,
				"tool_key": "hoe",
				"supply_key": "tool_hoe"
			}
		]
	},
	"freshwater_fish": {
		"title": "🏪 [NGƯ NƯƠNG HỒ ĐẦM] KHÊ HỒ NGƯ NƯƠNG",
		"location": "Tọa độ 180/185 (Bờ Suối Nước Ngọt)",
		"greeting": "🐟 \"Khách quan ghé thăm hồ Nguyệt Ca! Nước nguồn thanh khiết, tôm cá lội tung tăng. Hãy cầm cần trúc thả câu xem tài nghệ nhé!\"",
		"theme_color": Color(0.35, 0.80, 0.95),
		"items": [
			{
				"id": "tool_rod_bamboo",
				"name": "Cần Câu Trúc Hồ Đầm",
				"icon": "bamboo.png",
				"price_gold": 50,
				"price_xu": 0,
				"desc": "Cần câu trúc uốn cong mềm dẻo, chuyên trị các loài cá nước ngọt ven bờ suối.",
				"is_tool": true,
				"tool_key": "fishing_rod_bamboo"
			},
			{
				"id": "bait_worm",
				"name": "Mồi Trùng Đất Đầm Sen",
				"icon": "yuer.png",
				"price_gold": 5,
				"price_xu": 0,
				"desc": "Giun đất tươi đào ven bờ đầm sen, mồi khoái khẩu của cá trắm, cá chép hồ.",
				"supply_key": "bait_worm"
			},
			{
				"id": "fingerling_carp",
				"name": "Cá Trắm Cỏ Giống",
				"icon": "caoyu.png",
				"price_gold": 20,
				"price_xu": 0,
				"desc": "Cá con khoẻ mạnh thả vào ao hồ sơn trang nuôi dưỡng sinh sôi.",
				"supply_key": "fingerling_carp"
			},
			{
				"id": "fish_pot",
				"name": "Hũ Dưỡng Thủy Sản",
				"icon": "yuguan.png",
				"price_gold": 35,
				"price_xu": 0,
				"desc": "Bình gốm chứa nước suối giữ cá câu được luôn tươi sống không ươn.",
				"supply_key": "fish_pot"
			},
			{
				"id": "fresh_water_pot",
				"name": "Thùng Nước Suối Khoáng",
				"icon": "shuitong.png",
				"price_gold": 15,
				"price_xu": 0,
				"desc": "Nước suối khoáng tự nhiên từ đỉnh thác, dùng pha trà dưỡng cá thượng hạng.",
				"supply_key": "fresh_water_pot"
			},
			{
				"id": "grilled_fresh_fish",
				"name": "Cá Nướng Hồ Hương Vị",
				"icon": "kaoyu.png",
				"price_gold": 45,
				"price_xu": 0,
				"desc": "Cá suối nướng than hoa thơm nức mũi, hồi phục thể lực dồi dào.",
				"supply_key": "grilled_fresh_fish"
			}
		]
	},
	"ocean_fish": {
		"title": "🏪 [THUYỀN TRƯỞNG BIỂN SÂU] HẢI NGƯ THUYỀN TRƯỞNG",
		"location": "Tọa độ 196/197 (Cầu Tàu Bến Nam Hải)",
		"greeting": "⚓ \"Gió nam đang thổi mạnh, luồng cá biển sâu kéo về rạn đá! Mau sắm cần câu biển cường lực ra khơi cùng thuyền ta nào!\"",
		"theme_color": Color(0.30, 0.65, 1.0),
		"items": [
			{
				"id": "tool_rod_ocean",
				"name": "Cần Câu Biển Cường Lực",
				"icon": "diaogan.png",
				"price_gold": 120,
				"price_xu": 0,
				"desc": "Cần câu biển carbon gia cường chịu tải lớn, câu cá vược, cá hồi biển khơi.",
				"is_tool": true,
				"tool_key": "fishing_rod_ocean"
			},
			{
				"id": "bait_shrimp",
				"name": "Mồi Tôm Biển Tươi Rói",
				"icon": "xia.png",
				"price_gold": 15,
				"price_xu": 0,
				"desc": "Tôm biển tươi roi rói vỏ mỏng, mồi câu số một cho các loài hải sản đại dương.",
				"supply_key": "bait_shrimp"
			},
			{
				"id": "fingerling_sea_bass",
				"name": "Cá Vược Biển Giống",
				"icon": "bianyu.png",
				"price_gold": 50,
				"price_xu": 0,
				"desc": "Cá biển giống thả lồng bè ven bờ biển Nam Hải nuôi lớn lấy thịt thơm ngon.",
				"supply_key": "fingerling_sea_bass"
			},
			{
				"id": "grilled_sea_fish",
				"name": "Cá Biển Nướng Thượng Hạng",
				"icon": "gaojikaoyu.png",
				"price_gold": 80,
				"price_xu": 0,
				"desc": "Cá biển nướng muối ớt cay nồng béo ngậy, bồi bổ nguyên khí tuyệt hảo.",
				"supply_key": "grilled_sea_fish"
			},
			{
				"id": "sea_salt_barrel",
				"name": "Thùng Muối Biển Hạt To",
				"icon": "shuitong.png",
				"price_gold": 25,
				"price_xu": 0,
				"desc": "Muối hạt tinh khiết phơi từ nước biển sâu, bảo quản cá tươi suốt chuyến hải hành.",
				"supply_key": "sea_salt_barrel"
			},
			{
				"id": "jade_fish_token",
				"name": "Bạch Ngọc Hoa Tiêu Biển",
				"icon": "baiyu.png",
				"price_gold": 100,
				"price_xu": 0,
				"desc": "Bảo ngọc hoa tiêu chỉ hướng luồng hải lưu, gia tăng may mắn khi câu cá biển sâu.",
				"supply_key": "jade_fish_token"
			}
		]
	}
}

static func open_shop(parent: Node, category: String) -> void:
	if not SHOP_CATALOG.has(category):
		push_warning("FarmNPCShop: Danh mục không tồn tại: " + category)
		return

	# Xoá shop cũ nếu đang mở để tránh chồng lấn
	var existing = parent.get_node_or_null("FarmNPCShopWindow")
	if existing:
		existing.queue_free()

	var shop_data: Dictionary = SHOP_CATALOG[category]
	var shop_inst := FarmNPCShop.new()
	shop_inst.name = "FarmNPCShopWindow"
	shop_inst.layer = 120 # Nằm trên HUD thông thường
	shop_inst._build_ui(parent, shop_data, category)
	parent.add_child(shop_inst)

func _build_ui(root_parent: Node, data: Dictionary, category: String) -> void:
	# Lớp nền mờ tối
	var dark_overlay := ColorRect.new()
	dark_overlay.color = Color(0, 0, 0, 0.45)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	dark_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			queue_free()
	)
	add_child(dark_overlay)

	# Khung cửa sổ chính
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(640, 520)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -320
	win.offset_right = 320
	win.offset_top = -260
	win.offset_bottom = 260
	win.mouse_filter = Control.MOUSE_FILTER_STOP

	var theme_color: Color = data.get("theme_color", Color(0.9, 0.8, 0.3))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.10, 0.12, 0.98)
	bg.border_color = theme_color
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 18
	bg.content_margin_top = 16
	bg.content_margin_right = 18
	bg.content_margin_bottom = 16
	bg.shadow_color = Color(0, 0, 0, 0.6)
	bg.shadow_size = 12
	win.add_theme_stylebox_override("panel", bg)
	add_child(win)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	win.add_child(main_vbox)

	# 1. Header: Tiêu đề NPC + Tọa độ + Nút Đóng
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = str(data.get("title", "CỬA HÀNG NPC"))
	title_lbl.add_theme_color_override("font_color", theme_color)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_box.add_child(title_lbl)

	var loc_lbl := Label.new()
	loc_lbl.text = "📍 " + str(data.get("location", ""))
	loc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	loc_lbl.add_theme_font_size_override("font_size", 12)
	title_box.add_child(loc_lbl)

	header.add_child(title_box)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.1, 0.1, 0.8)
	close_style.border_color = Color(0.8, 0.3, 0.3)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# 2. Lời thoại chào hỏi của NPC
	var quote_panel := PanelContainer.new()
	var quote_box := StyleBoxFlat.new()
	quote_box.bg_color = Color(0.14, 0.15, 0.18, 0.8)
	quote_box.border_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.4)
	quote_box.set_border_width_all(1)
	quote_box.set_corner_radius_all(6)
	quote_box.content_margin_left = 12
	quote_box.content_margin_top = 8
	quote_box.content_margin_right = 12
	quote_box.content_margin_bottom = 8
	quote_panel.add_theme_stylebox_override("panel", quote_box)

	var quote_lbl := Label.new()
	quote_lbl.text = str(data.get("greeting", ""))
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_lbl.add_theme_font_size_override("font_size", 12)
	quote_lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	quote_panel.add_child(quote_lbl)
	main_vbox.add_child(quote_panel)

	if category == "livestock":
		var exchange_btn := Button.new()
		exchange_btn.text = "🍗 ĐỔI THỊT THU HOẠCH LẤY BẢO RƯƠNG & EXP (GẶP TRÙ THẦN) 🍗"
		exchange_btn.custom_minimum_size = Vector2(0, 34)
		exchange_btn.focus_mode = Control.FOCUS_NONE
		var ex_style := StyleBoxFlat.new()
		ex_style.bg_color = Color(0.18, 0.38, 0.22, 0.95)
		ex_style.border_color = Color(0.4, 0.9, 0.45)
		ex_style.set_border_width_all(1)
		ex_style.set_corner_radius_all(6)
		exchange_btn.add_theme_stylebox_override("normal", ex_style)
		exchange_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		exchange_btn.pressed.connect(func():
			queue_free()
			var script_win = load("res://ui/son_trang/farm_windows.gd")
			if script_win != null and script_win.has_method("open_meat_exchange"):
				script_win.open_meat_exchange(root_parent)
		)
		main_vbox.add_child(exchange_btn)

	# 3. Thanh hiển thị ngân lượng hiện có của người chơi
	var balance_hbox := HBoxContainer.new()
	balance_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var balance_lbl := Label.new()
	balance_lbl.name = "BalanceLabel"
	_update_balance_text(balance_lbl)
	balance_lbl.add_theme_font_size_override("font_size", 13)
	balance_hbox.add_child(balance_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_hbox.add_child(spacer)

	var tip_lbl := Label.new()
	tip_lbl.text = "💡 Mua xong vật phẩm sẽ cất vào Rương Sơn Trang"
	tip_lbl.add_theme_font_size_override("font_size", 11)
	tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	balance_hbox.add_child(tip_lbl)

	main_vbox.add_child(balance_hbox)

	# 4. Danh sách vật phẩm cuộn dọc
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vbox)

	var items: Array = data.get("items", [])
	for item_info in items:
		var row := _build_item_row(item_info, balance_lbl, root_parent)
		list_vbox.add_child(row)

	# 5. Footer: Nút Xem Rương & Nút Đóng
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)

	var chest_btn := Button.new()
	chest_btn.text = "📦 Mở Rương Sơn Trang"
	chest_btn.custom_minimum_size = Vector2(160, 36)
	chest_btn.focus_mode = Control.FOCUS_NONE
	chest_btn.pressed.connect(func():
		var fw_script: GDScript = load("res://ui/son_trang/farm_windows.gd")
		if fw_script:
			fw_script.open_chest(root_parent)
	)
	footer.add_child(chest_btn)

	var bottom_close_btn := Button.new()
	bottom_close_btn.text = "Đóng"
	bottom_close_btn.custom_minimum_size = Vector2(100, 36)
	bottom_close_btn.focus_mode = Control.FOCUS_NONE
	bottom_close_btn.pressed.connect(queue_free)
	footer.add_child(bottom_close_btn)

	main_vbox.add_child(footer)

func _build_item_row(item: Dictionary, balance_lbl: Label, _root_parent: Node) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var row_box := StyleBoxFlat.new()
	row_box.bg_color = Color(0.12, 0.13, 0.16, 0.90)
	row_box.border_color = Color(0.25, 0.28, 0.32)
	row_box.set_border_width_all(1)
	row_box.set_corner_radius_all(6)
	row_box.content_margin_left = 10
	row_box.content_margin_top = 8
	row_box.content_margin_right = 10
	row_box.content_margin_bottom = 8
	row_panel.add_theme_stylebox_override("panel", row_box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)

	# Icon / Hình ảnh thật từ source:
	# Nếu là động vật hoặc chim -> Ưu tiên lấy trực tiếp sprite động vật từ MonsterData / Monster sheet VLTK
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(58, 58)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var loaded := false
	if item.has("monster_res"):
		var mres: String = str(item["monster_res"])
		var thumb_tex := MonsterData.thumb(mres)
		if thumb_tex != null:
			icon_rect.texture = thumb_tex
			loaded = true
		else:
			var act := MonsterData.action(mres, "stand")
			var anim_key: String = str(act.get("anim", ""))
			if anim_key != "":
				var anim_info: Dictionary = MonsterData.anim(anim_key)
				var size_arr: Array = anim_info.get("size", [])
				var tex: Texture2D = MonsterData.texture(anim_key)
				if tex != null and size_arr.size() >= 2:
					var atlas := AtlasTexture.new()
					atlas.atlas = tex
					atlas.region = Rect2(0, 0, float(size_arr[0]), float(size_arr[1]))
					icon_rect.texture = atlas
					loaded = true

	if not loaded:
		var icon_name: String = str(item.get("icon", ""))
		if icon_name == "chuizi.png":
			icon_name = "chan.png"
		var farm_icon_path: String = "res://assets/farm/icons/" + icon_name
		var full_icon_path: String = ICON_PATH_PREFIX + icon_name
		if ResourceLoader.exists(farm_icon_path):
			icon_rect.texture = load(farm_icon_path)
		elif ResourceLoader.exists(full_icon_path):
			icon_rect.texture = load(full_icon_path)
		else:
			var res_farm = load(farm_icon_path)
			if res_farm is Texture2D:
				icon_rect.texture = res_farm
			else:
				var res_items = load(full_icon_path)
				if res_items is Texture2D:
					icon_rect.texture = res_items
				else:
					icon_rect.texture = load("res://assets/farm/crops/seed.png")
	
	# Khung viền ảnh đại diện (Động vật / Chim / Vật phẩm)
	var icon_container := PanelContainer.new()
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = Color(0.06, 0.07, 0.08)
	icon_box.border_color = Color(0.80, 0.68, 0.25) if item.has("monster_res") else Color(0.45, 0.45, 0.35)
	icon_box.set_border_width_all(2 if item.has("monster_res") else 1)
	icon_box.set_corner_radius_all(6)
	icon_box.content_margin_left = 3
	icon_box.content_margin_top = 3
	icon_box.content_margin_right = 3
	icon_box.content_margin_bottom = 3
	icon_container.add_theme_stylebox_override("panel", icon_box)
	icon_container.add_child(icon_rect)
	hbox.add_child(icon_container)

	# Chi tiết tên, phân loại, công dụng và sản lượng
	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 2)

	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "Vật phẩm"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	title_hbox.add_child(name_lbl)

	if item.has("category_tag"):
		var tag_lbl := Label.new()
		tag_lbl.text = "[%s]" % str(item["category_tag"])
		tag_lbl.add_theme_font_size_override("font_size", 11)
		tag_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.9))
		title_hbox.add_child(tag_lbl)

	detail_vbox.add_child(title_hbox)

	var desc_lbl := Label.new()
	desc_lbl.text = str(item.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	detail_vbox.add_child(desc_lbl)

	if item.has("harvest_prod"):
		var harvest_lbl := Label.new()
		var grow_min: float = float(item.get("grow_time", 120)) / 60.0
		harvest_lbl.text = "📦 Sản lượng thu hoạch: %s  |  ⏱️ Thời gian lớn: %.1f phút" % [item["harvest_prod"], grow_min]
		harvest_lbl.add_theme_font_size_override("font_size", 10)
		harvest_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		detail_vbox.add_child(harvest_lbl)

	hbox.add_child(detail_vbox)

	# Cột giá tiền & Nút Mua
	var buy_vbox := VBoxContainer.new()
	buy_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_vbox.custom_minimum_size = Vector2(120, 0)
	buy_vbox.add_theme_constant_override("separation", 4)

	var price_gold: int = int(item.get("price_gold", 0))
	var price_xu: int = int(item.get("price_xu", 0))
	var price_text := ""
	if price_gold > 0:
		price_text += "%d Lượng " % price_gold
	if price_xu > 0:
		price_text += "%d Xu" % price_xu
	
	var price_lbl := Label.new()
	price_lbl.text = "💰 " + price_text
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	buy_vbox.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Mua Nuôi" if item.has("monster_res") else "Mua"
	buy_btn.custom_minimum_size = Vector2(100, 30)
	buy_btn.focus_mode = Control.FOCUS_NONE

	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = Color(0.20, 0.35, 0.20, 0.95)
	buy_style.border_color = Color(0.4, 0.8, 0.4)
	buy_style.set_border_width_all(1)
	buy_style.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", buy_style)

	buy_btn.pressed.connect(func():
		_execute_purchase(item, buy_btn, balance_lbl)
	)
	buy_vbox.add_child(buy_btn)
	hbox.add_child(buy_vbox)

	return row_panel

func _execute_purchase(item: Dictionary, btn: Button, balance_lbl: Label) -> void:
	var farm_mgr: FarmManager = get_node_or_null("/root/FarmManager")
	if farm_mgr == null:
		btn.text = "Lỗi hệ thống!"
		return

	var price_gold: int = int(item.get("price_gold", 0))
	var price_xu: int = int(item.get("price_xu", 0))

	# Kiểm tra và trừ tiền
	if not farm_mgr.buy_item_with_currency(price_gold, price_xu):
		btn.text = "Thiếu tiền!"
		var err_timer := get_tree().create_timer(1.2)
		err_timer.timeout.connect(func(): if is_instance_valid(btn): btn.text = "Mua Nuôi" if item.has("monster_res") else "Mua")
		return

	# Xử lý cấp công cụ hoặc thêm vào rương vật tư
	if item.get("is_tool", false):
		var tool_key: String = str(item.get("tool_key", ""))
		if tool_key != "":
			farm_mgr.owned_tools[tool_key] = true
	
	var supply_key: String = str(item.get("supply_key", item.get("id", "")))
	if supply_key != "":
		farm_mgr.add_to_chest(supply_key, 1, true)

	# Xử lý nếu là con vật nuôi / loài chim -> đưa vào rương đồ (người chơi phải mang vào Vòng Nuôi Thú mới thả)
	if item.has("monster_res") or item.has("animal_id"):
		btn.text = "✓ Đã Vào Rương"
		var tree := get_tree()
		if tree != null:
			var player = tree.get_first_node_in_group("player")
			if player != null and is_instance_valid(player) and player.has_method("notify"):
				player.notify("📦 Đã đưa %s vào Rương đồ! Hãy mang tới Vòng Nuôi Thú để thả." % str(item.get("name", "Vật nuôi")))
	else:
		btn.text = "✓ Đã Mua"

	# Lưu dữ liệu sơn trang & phát tín hiệu cập nhật hình ảnh con vật ở khu chuồng
	farm_mgr.save_farm_data()
	farm_mgr.farm_data_changed.emit()

	# Cập nhật số dư người chơi
	_update_balance_text(balance_lbl)

	# Reset chữ nút sau 1.2s
	var success_timer := get_tree().create_timer(1.2)
	success_timer.timeout.connect(func():
		if is_instance_valid(btn):
			btn.text = "Mua Nuôi" if item.has("monster_res") else "Mua"
	)

func _update_balance_text(lbl: Label) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var profile: PlayerProfile = gm.local_profile if (gm and "local_profile" in gm) else null
	if profile != null:
		lbl.text = "💰 Ngân lượng: %d Lượng  |  🪙 Tiền xu: %d Xu" % [profile.gold, profile.xu]
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	else:
		lbl.text = "💰 Ngân lượng: 0 Lượng  |  🪙 Tiền xu: 0 Xu"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
