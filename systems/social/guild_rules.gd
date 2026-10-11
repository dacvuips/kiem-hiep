extends RefCounted
class_name GuildRules
## Hằng số + hàm thuần của BANG HỘI (KPlayerTong / KTongData gốc). Chức vụ theo enum TONG_MEMBER_FIGURE: Đệ tử < Đội trưởng < Trưởng lão <
## Bang chủ (+ Ẩn sĩ — đã nghỉ hưu, không tính chỉ tiêu). Giới hạn lấy từ data/social/social_rules.json (xem tools/import_vltk_social_rules.py).

enum Figure { MEMBER, MANAGER, DIRECTOR, MASTER }

const CAMPS := [Camp.Type.JUSTICE, Camp.Type.EVIL, Camp.Type.BALANCE]   ## phe được chọn khi lập bang

static func figure_name(figure: int) -> String:
	var call: Dictionary = SocialRules.tong()["default_call"]
	match figure:
		Figure.MASTER:
			return str(call["master"])
		Figure.DIRECTOR:
			return str(call["director"])
		Figure.MANAGER:
			return str(call["manager"])
	return str(call["normal"])

static func max_for_figure(figure: int) -> int:
	match figure:
		Figure.MASTER:
			return 1
		Figure.DIRECTOR:
			return int(SocialRules.tong()["max_director"])
		Figure.MANAGER:
			return int(SocialRules.tong()["max_manager"])
	return 1 << 20

## Ai được bổ nhiệm ai — KPlayerTong::CheckInstate gốc: Bang chủ đổi mọi chức (trừ Bang chủ); Trưởng lão chỉ đổi giữa Đội trưởng <-> Đệ tử.
static func can_instate(actor_figure: int, current_figure: int, new_figure: int) -> bool:
	if new_figure == current_figure or new_figure == Figure.MASTER or current_figure == Figure.MASTER:
		return false
	match actor_figure:
		Figure.MASTER:
			return true
		Figure.DIRECTOR:
			return current_figure in [Figure.MANAGER, Figure.MEMBER] and new_figure in [Figure.MANAGER, Figure.MEMBER]
	return false

## Ai được đuổi ai — Bang chủ đuổi được Trưởng lão/Đội trưởng/Đệ tử, Trưởng lão chỉ đuổi Đội trưởng/Đệ tử (gốc: KickMember).
static func can_kick(actor_figure: int, target_figure: int) -> bool:
	if actor_figure == Figure.MASTER:
		return target_figure != Figure.MASTER
	if actor_figure == Figure.DIRECTOR:
		return target_figure in [Figure.MANAGER, Figure.MEMBER]
	return false

static func is_valid_name(tong_name: String) -> bool:
	var n := tong_name.strip_edges()
	return n != "" and n.length() <= int(SocialRules.tong()["name_max_length"])

## ---- Quyền hạn (màn "Phân phối chức năng"): Bang chủ luôn có đủ; Bang chủ có thể trao từng quyền cho thành viên khác. ----
const PERM_INSTATE := "instate"      ## Bổ nhiệm – miễn
const PERM_LOG := "log"              ## Nhật ký (sửa công cáo / thêm sự việc)
const PERM_RENAME := "rename"        ## Đổi tên bang
const PERM_KICK := "kick"            ## Trục xuất
const PERMS := [PERM_INSTATE, PERM_LOG, PERM_RENAME, PERM_KICK]
const PERM_NAMES := {PERM_INSTATE: "Bổ nhiệm – miễn", PERM_LOG: "Nhật ký", PERM_RENAME: "Đổi tên", PERM_KICK: "Trục xuất"}

## Quyền mặc định theo chức vụ khi mới vào/được bổ nhiệm (thiết kế của game: gốc lưu theo từng thành viên trên server).
static func default_perms(figure: int) -> Array:
	match figure:
		Figure.MASTER:
			return PERMS.duplicate()
		Figure.DIRECTOR:
			return [PERM_INSTATE, PERM_LOG, PERM_KICK]
		Figure.MANAGER:
			return [PERM_LOG]
	return []

## Khuynh hướng / hoạt động chính của bang (màn "Chiêu Mộ"). Giá trị đầu mỗi danh sách ("Thích PK", "Tống Kim") lấy từ ảnh màn gốc,
## phần còn lại là gợi ý của game.
const TENDENCIES := ["Thích PK", "Yêu hoà bình", "Luyện cấp", "Giao lưu kết bạn"]
const ACTIVITIES := ["Tống Kim", "Luyện công", "Bang chiến", "Săn boss", "Giao hữu"]
