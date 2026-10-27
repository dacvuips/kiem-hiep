extends RefCounted
class_name MockPlayer
## NGƯỜI CHƠI GIẢ để chơi một mình: đóng vai những người chơi khác ở quanh (tổ đội, bang hội, giao dịch, bày bán). Mỗi người có tên,
## cấp, môn phái, tiền, túi đồ, quầy bày bán... Khi game chạy online, danh sách này đến từ server thay vì sinh cục bộ — giao diện và
## dịch vụ (TeamService, GuildService, TradeSession, StallService) chỉ dùng các trường dưới đây nên không phải sửa.

var id: int = 0
var name: String = ""
var level: int = 1
var sect_id: String = ""
var sect_name: String = ""
var female: bool = false
var lead_level: int = 0
var camp: int = 0                   ## Camp.Type của bang (0 chính phái... theo GuildRules)
var fuyuan: int = 0
var repute: int = 0
var gold: int = 0
var bag := ItemContainer.new(10, 6, 1)         ## túi đồ của người này (để giao dịch / bày bán)
var trade_open: bool = true                      ## đang "mở giao dịch" (cho phép người khác xin giao dịch)
var stall_open: bool = false
var stall_title: String = ""
var guild_name: String = ""                      ## "" = chưa vào bang
var guild_figure: int = 0                        ## GuildRules.Figure
var recruit: bool = false                        ## đang tuyển người (chỉ bang chủ/trưởng lão)
var invite_accept_rate: float = 0.75             ## xác suất đồng ý lời mời tổ đội/bang
var equipment: Dictionary = {}                   ## Equipment.Part -> ItemInstance đang mặc (để người khác xem trang bị)
var custom_avatar: String = ""                   ## Chuỗi base64 ảnh đại diện tùy chỉnh 200x200 JPG
var team_tag: String = ""                       ## "" = không ở trong đội; "c" = đội trưởng đội giả; "t" = thành viên đội của người chơi
var haggle: float = 0.9                          ## hệ số: người này chỉ giao dịch khi giá trị mình nhận >= haggle * giá trị mình đưa

## Giá gợi ý của 1 món (để người chơi giả đặt giá / định giá khi giao dịch). Công thức là THIẾT KẾ của game này (gốc không có
## bảng giá bán giữa người chơi): cấp món, số dòng thuộc tính và hoàng kim quyết định.
static func suggested_price(item: ItemInstance) -> int:
	var lines := item.magic.size() + item.expand_magic.size()
	var base := 300 * item.get_level() * item.get_level()
	if item.is_gold():
		base *= 6
	return maxi(100, base + lines * 4000 * maxi(1, item.get_level()))

func total_value(items: Array, money: int) -> int:
	var v := money
	for it in items:
		v += suggested_price(it)
	return v

func level_text() -> String:
	return "Cấp %d" % level

func figure_text() -> String:
	return GuildRules.figure_name(guild_figure) if guild_name != "" else ""
