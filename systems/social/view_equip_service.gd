extends RefCounted
class_name ViewEquipService
## XEM TRANG BỊ NGƯỜI CHƠI KHÁC — theo c2s_viewequip / KProtocolProcess::c2sViewEquip / KPlayer::SendEquipItemInfo / KViewItem của VLTK gốc:
##   - Client gửi mã người cần xem; server chặn nếu xem QUÁ NHANH (cách nhau < defMAX_VIEW_EQUIP_TIME = 30 nhịp game = 30/18 giây),
##     chặn xem CHÍNH MÌNH, và người kia phải đang Ở GẦN (FindAroundPlayer).
##   - Server trả về từng ô trang bị (itempart_num ô) dưới dạng THAM SỐ SINH ĐỒ (id, loại, cấp, may mắn, hạt giống, các cấp dòng thuộc tính...),
##     client dựng lại món đồ từ tham số đó (ItemSet.Add) rồi hiện — nên bản xem là BẢN SAO, không đụng được món thật của người kia.
##   - Kèm tên, cấp, hình nhân vật (m_Avatar) của người kia.
## Ở game này người ở gần = danh sách SocialDirectory; online thì server gửi snapshot cùng định dạng (xem `snapshot_of_profile`).

const COOLDOWN_MS := 1667          ## 30 nhịp / 18 nhịp mỗi giây
static var _last_view_ms: Dictionary = {}

static func reset() -> void:
	_last_view_ms.clear()

## Xem trang bị của `target`. Trả về {"error": "" hoặc lời báo lỗi, "snapshot": Dictionary (khi thành công)}.
static func view(viewer: PlayerProfile, target: MockPlayer, now_ms: int = -1) -> Dictionary:
	var now := now_ms if now_ms >= 0 else Time.get_ticks_msec()
	var key := viewer.get_instance_id()
	if _last_view_ms.has(key) and now - int(_last_view_ms[key]) < COOLDOWN_MS:
		var wait := int(ceil((COOLDOWN_MS - (now - int(_last_view_ms[key]))) / 1000.0))
		return {"error": "Xem trang bị quá nhanh, hãy đợi %d giây." % maxi(1, wait)}
	_last_view_ms[key] = now
	if target == null:
		return {"error": "Không thấy người chơi này."}
	if target.name == viewer.display_name:
		return {"error": "Không thể xem trang bị của chính mình ở đây."}
	if SocialDirectory.find_by_id(viewer, target.id) == null:
		return {"error": "%s không ở gần bạn." % target.name}
	return {"error": "", "snapshot": snapshot_of_mock(target)}

## Bản chụp để hiển thị — mỗi món là BẢN SAO dựng lại từ dữ liệu sinh đồ (giống KViewItem::GetData).
static func snapshot_of_mock(m: MockPlayer) -> Dictionary:
	var copies := {}
	for part in m.equipment:
		copies[part] = ItemInstance.from_dict((m.equipment[part] as ItemInstance).to_dict())
	var sect := SectRegistry.get_by_id(m.sect_id)
	return {
		"name": m.name, "level": m.level, "sect_name": m.sect_name, "sect_id": m.sect_id,
		"series": int(sect.element) if sect else 0, "camp": m.camp, "female": m.female,
		"guild": m.guild_name, "lead_level": m.lead_level, "equipment": copies,
	}

## Online: bản chụp đi qua mạng (JSON) — ItemInstance đổi thành dữ liệu, khoá ô trang bị thành chuỗi.
static func snapshot_to_wire(snap: Dictionary) -> Dictionary:
	var out := snap.duplicate()
	var eq := {}
	for part in snap.get("equipment", {}):
		eq[str(part)] = (snap["equipment"][part] as ItemInstance).to_dict()
	out["equipment"] = eq
	return out

## Dựng lại bản chụp nhận từ server (ngược với snapshot_to_wire); bỏ món hỏng.
static func snapshot_from_wire(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	var eq := {}
	var raw: Variant = d.get("equipment", {})
	if raw is Dictionary:
		for k in raw:
			if raw[k] is Dictionary and str(k).is_valid_int():
				var it := ItemInstance.from_dict(raw[k])
				if it != null:
					eq[int(k)] = it
	out["equipment"] = eq
	for k in ["level", "series", "camp", "lead_level"]:
		out[k] = int(out.get(k, 0))
	return out

## Định dạng cho CHÍNH người chơi (online: gửi cho người đang xem mình).
static func snapshot_of_profile(p: PlayerProfile) -> Dictionary:
	var copies := {}
	for part in p.equipment:
		copies[part] = ItemInstance.from_dict((p.equipment[part] as ItemInstance).to_dict())
	var sect := SectRegistry.get_by_id(p.sect_id)
	return {
		"name": p.display_name, "level": p.level, "sect_name": p.sect_name, "sect_id": p.sect_id,
		"series": int(sect.element) if sect else 0, "camp": p.get_current_camp(), "female": p.gender == PlayerProfile.Gender.FEMALE,
		"guild": str(p.guild.get("name", "")), "lead_level": p.lead_level, "equipment": copies,
	}
