extends RefCounted
class_name ExpRules
## Công thức chia KINH NGHIỆM theo VLTK gốc (KPlayer::AddSelfExp / AddExp / AddLeadExp, KNpcDeathCalcExp::CalcExp).

const SHARE_DISTANCE := 768            ## PLAYER_SHARE_EXP_DISTANCE: đồng đội cách quái xa hơn mức này không được chia
const LEAD_EXP_SHARE := 25             ## LeadExpShare (level_add.txt gốc, cả 5 hệ cùng 25)

## KPlayer::AddSelfExp — kinh nghiệm thực nhận khi đánh quái cấp `target_level` (chưa nhân hệ số exp của trang bị).
## Chênh cấp <= 5: đủ; 6..15: giảm dần; > 15: chỉ 1. Người >= cấp quái và quái cấp >= 100: trừ nexp * chênh / 200.
static func self_exp(player_level: int, target_level: int, exp: int) -> int:
	if exp <= 0:
		return 0
	var diff := absi(player_level - target_level)
	var got := 0
	if player_level >= target_level and target_level >= 100:
		got = exp - exp * diff / 200
	elif diff <= 5:
		got = exp
	elif diff <= 15:
		got = exp * (295 - 19 * diff) / 200
	else:
		got = 1
	return maxi(1, got)

## KPlayer::AddExp (nhánh tổ đội) — chia `exp` cho các thành viên trong tầm. `levels` = cấp từng người ĐANG TRONG TẦM (phần tử 0 nên là
## đội trưởng nếu ở trong tầm; người ngoài tầm không đưa vào). Mỗi người nhận exp * (k * cấp_của_họ / tổng_cấp) / 100, k = 100 + 15 * số người.
## Trả về mảng exp (chưa qua self_exp), cùng thứ tự `levels`. Một người = nhận hết.
static func team_shares(exp: int, levels: Array) -> Array:
	var n := levels.size()
	var out := []
	if n == 0:
		return out
	if n == 1:
		return [exp]
	var total_level := 0
	for lv in levels:
		total_level += int(lv)
	total_level = maxi(1, total_level)
	var k := 100 + n * 15
	for lv in levels:
		var pct := k * int(lv) / total_level
		if pct <= 0:
			pct = 1
		out.append(exp * pct / 100)
	return out

## Kinh nghiệm LÃNH ĐẠO đội trưởng nhận mỗi lần chia: exp * k * LeadExpShare * (tổng_cấp - cấp_đội_trưởng) / (tổng_cấp * 10000).
static func lead_exp(exp: int, levels: Array, captain_level: int) -> int:
	var n := levels.size()
	if n <= 1:
		return 0
	var total_level := 0
	for lv in levels:
		total_level += int(lv)
	if total_level <= 0:
		return 0
	var k := 100 + n * 15
	return exp * k * LEAD_EXP_SHARE * (total_level - captain_level) / (total_level * 10000)

## Cộng kinh nghiệm lãnh đạo vào hồ sơ, lên cấp theo bảng (KPlayer::AddLeadExp). Trả về số cấp lãnh đạo tăng.
static func add_lead_exp(p: PlayerProfile, amount: int) -> int:
	if amount <= 0 or p.lead_level >= SocialRules.max_lead_level():
		return 0
	p.lead_exp += amount
	var gained := 0
	while p.lead_level < SocialRules.max_lead_level() and p.lead_exp >= SocialRules.lead_exp_to_next(p.lead_level):
		p.lead_level += 1
		gained += 1
	return gained
