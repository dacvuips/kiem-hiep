extends SceneTree
## Xuất DANH MỤC cho web Admin (server/admin-web/public/catalog.json): đồ thường, đồ hoàng kim, môn phái + skill, tên ô trang bị.
## Web Admin không có dữ liệu game nên đọc file này để hiện tên món / tên skill và chọn đồ khi thêm vào hành trang.
## Chạy lại mỗi khi đổi dữ liệu đồ / skill:
##   godot --headless --path . --script tools/export_admin_catalog.gd

const OUT_PATH := "res://server/admin-web/public/catalog.json"

func _initialize() -> void:
	var equip := []
	var i := 0
	while true:
		var b := ItemDatabase.get_base(i)
		if b.is_empty():
			break
		var size := ItemDatabase.size_of(b)
		equip.append({"i": i, "n": b.get("name", ""), "d": int(b.get("detail", 0)), "p": int(b.get("particular", 0)),
			"l": int(b.get("level", 1)), "s": int(b.get("series", -1)), "w": size.x, "h": size.y})
		i += 1
	var gold := []
	i = 0
	while true:
		var g := ItemDatabase.get_gold(i)
		if g.is_empty():
			break
		var gsize := ItemDatabase.size_of(g)
		gold.append({"i": i, "n": g.get("name", ""), "d": int(g.get("detail", 0)), "p": int(g.get("particular", 0)),
			"l": int(g.get("level", 1)), "s": int(g.get("series", 0)), "m": int(g.get("menpai", -1)), "g": int(g.get("group", 0)),
			"w": gsize.x, "h": gsize.y})
		i += 1
	var details := {}
	for d in ItemDatabase.DETAIL_NAMES:
		details[str(d)] = ItemDatabase.DETAIL_NAMES[d]
	var particulars := {}
	for d in ItemDatabase.DETAIL_NAMES:
		var row := {}
		for p in ItemDatabase.get_particulars(d):
			row[str(p)] = ItemDatabase.get_particular_label(d, p)
		particulars[str(d)] = row
	var parts := {}
	for p in Equipment.PART_NAMES:
		parts[str(p)] = Equipment.PART_NAMES[p]
	var sects := []
	for sect in SectRegistry.load_all():
		var skills := []
		for s in sect.skills:
			if s == null or s.id == "" or s.is_hidden or s.parent_skill_id != "" or s.id.begins_with("basic_attack"):
				continue
			skills.append({"id": s.id, "n": s.skill_name, "max": s.max_level, "req": s.req_level})
		sects.append({"id": sect.id, "n": sect.sect_name, "skills": skills})
	sects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var out := {"equip": equip, "gold": gold, "details": details, "particulars": particulars, "parts": parts,
		"menpai": Equipment.MENPAI_ORDER, "sects": sects,
		"room": {"w": PlayerProfile.ROOM_WIDTH, "h": PlayerProfile.ROOM_HEIGHT, "bags": PlayerProfile.OPEN_BAGS},
		"storage": {"w": 6, "h": 10, "max_extra": StorageService.MAX_EXTRA_BOXES}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("Đã xuất %d đồ thường, %d đồ hoàng kim, %d môn phái -> %s" % [equip.size(), gold.size(), sects.size(), OUT_PATH])
	quit()
