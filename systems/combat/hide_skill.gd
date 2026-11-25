class_name HideSkill
## Skill ẨN THÂN (thuộc tính "hide" gốc) — dùng chung game và game server để 2 bên tính cùng 1 thời gian ẩn.
##   - Ngự Tuyết Ẩn (Thúy Yên 120, skill 713): bản thân skill có "hide" (cuiyan.lua cuiyan120: 5 -> 30 giây).
##   - Huyền Băng Vô Tắc (Thúy Yên 180, advancedskill.lua cy_adskill): bị đánh trúng có xác suất tự thi triển
##     Dung Tuyết Vô Tung (skill 1235) -> ẩn thân Link(cấp, {1, 2*18}, {20, 5*18}) frame.
## Gốc: đang ẩn thì quái / người khác không thấy, không chọn làm mục tiêu; thi triển võ công là hiện hình.

const DUNG_TUYET_VO_TUNG := 1235
const HUYEN_BANG_VO_TAC_ID := "thuy_yen_huyen_bang_vo_tac"
## cy_adskill.hide[2] gốc (thành phần thời gian, frame): {{1, 2*18}, {20, 5*18}}.
const DUNG_TUYET_FRAMES := [1, 36, 0, 20, 90, 0]
## Trần thời gian ẩn server nhận (Ngự Tuyết Ẩn cấp cao nhất 30 giây).
const MAX_SECONDS := 30.0

## Thời gian ẩn của Dung Tuyết Vô Tung khi Huyền Băng Vô Tắc ở `level`.
static func dung_tuyet_seconds(level: int) -> float:
	return SkillDefinition.frames_to_seconds(SkillDefinition.eval_level_points(PackedFloat32Array(DUNG_TUYET_FRAMES), clampi(level, 1, 20)))

## autoreplyskill gốc (KNpcAttribModify::AutoReplySkill): thành phần [2] = giãn cách(frame) * 256 + tỷ lệ(%).
## Trả về {"rate": %, "wait": giây}.
static func auto_reply(skill: SkillDefinition, level: int) -> Dictionary:
	var v := skill.get_attrib("autoreplyskill", level).z if skill != null else 0
	return {"rate": v % 256, "wait": SkillDefinition.frames_to_seconds(v / 256)}

## Skill `skill` có phải skill ẩn thân chủ động (mang "hide") không.
static func is_hide_skill(skill: SkillDefinition) -> bool:
	return skill != null and skill.has_attrib("hide")

## Thời gian ẩn (giây) của skill ẩn thân `skill` ở `level` (0 nếu không phải).
static func seconds_of(skill: SkillDefinition, level: int) -> float:
	if not is_hide_skill(skill):
		return 0.0
	return SkillDefinition.frames_to_seconds(skill.get_attrib("hide", level).y)
