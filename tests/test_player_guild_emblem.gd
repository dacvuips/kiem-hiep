extends Node
## Kiểm thử tên nhân vật, tên bang hội và biểu tượng bang hội trên Player, RemotePlayer và GuildWindow.

const PlayerScene := preload("res://player/player.tscn")
const GuildEmblem = preload("res://systems/social/guild_emblem.gd")
const GuildTag = preload("res://ui/guild_tag.gd")

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	_test_guild_emblem()
	_test_guild_service_emblem()
	_test_player_name_and_guild()
	_test_remote_player_guild()
	await _test_guild_window_ui()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _test_guild_emblem() -> void:
	check("GuildEmblem: có đủ 12 mẫu biểu tượng", GuildEmblem.count() == 12, GuildEmblem.count())
	for i in range(1, GuildEmblem.count() + 1):
		var tex := GuildEmblem.get_texture(i)
		if tex == null or tex.get_size() != Vector2(16, 16):
			check("GuildEmblem: texture mẫu %d hợp lệ" % i, false)
			return
	check("GuildEmblem: tất cả 12 texture 16x16 hợp lệ", true)
	check("GuildEmblem: bang chưa lưu emblem tự suy ra id 1..12", GuildEmblem.resolve_id({"name": "VietMU"}) >= 1)
	check("GuildEmblem: tên biểu tượng không rỗng", GuildEmblem.emblem_name(1) != "")
	var picker := GuildEmblem.create_picker(3)
	check("GuildEmblem: picker trả đúng id ban đầu", picker["get_selected"].call() == 3)
	(picker["node"] as Node).free()

func _test_guild_service_emblem() -> void:
	var prof := PlayerProfile.new()
	prof.display_name = "KnightVN"
	prof.level = 80
	prof.lead_level = 30
	prof.gold = 50_000_000
	prof.prestige = 500
	prof.fuyuan = 500
	var svc := GuildService.new(prof)
	var err := svc.create("VietMU", Camp.Type.JUSTICE, null, 5)
	check("GuildService: tạo bang kèm biểu tượng 5 thành công", err == "", err)
	check("GuildService: lưu emblem = 5 trong profile.guild", int(prof.guild.get("emblem", 0)) == 5)
	check("GuildService: emblem_id() trả 5", svc.emblem_id() == 5)
	var err2 := svc.set_emblem(8)
	check("GuildService: Bang chủ đổi biểu tượng sang 8 thành công", err2 == "", err2)
	check("GuildService: emblem_id() cập nhật sang 8", svc.emblem_id() == 8)

func _test_player_name_and_guild() -> void:
	var prof := PlayerProfile.new()
	prof.display_name = "KnightVN"
	prof.level = 50
	prof.sect_id = "thieu_lam"
	prof.guild = {
		"name": "VietMU",
		"camp": Camp.Type.JUSTICE,
		"emblem": 4,
		"members": [{"name": "KnightVN", "figure": GuildRules.Figure.MASTER, "level": 50, "local": true}],
	}
	GameManager.local_profile = prof

	var player := PlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame

	var lbl: Label = player._name_label
	var gt: GuildTag = player._guild_tag
	check("Player: _name_label hiển thị đúng tên nhân vật", lbl != null and lbl.text == "KnightVN" and lbl.visible)
	check("Player: _name_label có z_index >= 12 để không bị che", lbl != null and lbl.z_index >= 12)
	check("Player: _guild_tag hiển thị khi có bang", gt != null and gt.visible and gt.has_guild())
	check("Player: _guild_tag hiển thị [VietMU] và đúng emblem 4", gt != null and gt._text == "[VietMU]" and gt._emblem_id == 4)
	check("Player: _guild_tag nằm phía trên _name_label", gt != null and lbl != null and gt.position.y < lbl.position.y)

	player.set_name_label_visible(false)
	check("Player: set_name_label_visible(false) ẩn tên và guild", not lbl.visible and not gt.visible)
	player.set_name_label_visible(true)
	check("Player: set_name_label_visible(true) hiện lại tên và guild", lbl.visible and gt.visible)

	SocialHub.of(prof).guild.set_emblem(9)
	check("Player: đổi emblem trong GuildService tự cập nhật GuildTag", gt._emblem_id == 9)

	prof.guild = {}
	SocialHub.of(prof).guild.changed.emit()
	check("Player: rời bang thì GuildTag tự ẩn", not gt.visible and not gt.has_guild())

	player.queue_free()
	SocialHub.forget(prof)
	GameManager.local_profile = null

func _test_remote_player_guild() -> void:
	var rp := RemotePlayer.new()
	add_child(rp)
	rp.setup({
		"eid": 1001,
		"name": "ElfXinhDep",
		"level": 60,
		"camp": Camp.Type.BALANCE,
		"nation": 0,
		"stall_title": "",
		"guild_name": "ThanhLong",
		"guild_emblem": 2,
		"pos": Vector2(200, 200),
		"dir": 0,
		"action": 0,
		"z": 0,
		"flags": 0,
		"hp": 100,
		"look": {"gender": 1, "helm": 0, "armor": 1, "weapon": 1, "horse": -1}
	})
	check("RemotePlayer: tên hiển thị và z_index >= 12", rp._label != null and rp._label.text == "ElfXinhDep" and rp._label.z_index >= 12)
	check("RemotePlayer: GuildTag hiển thị [ThanhLong] và emblem 2", rp._guild_tag != null and rp._guild_tag.visible and rp._guild_tag._text == "[ThanhLong]" and rp._guild_tag._emblem_id == 2)
	rp.set_guild("HoangKim", 6)
	check("RemotePlayer: set_guild cập nhật tên bang & emblem", rp._guild_tag._text == "[HoangKim]" and rp._guild_tag._emblem_id == 6)
	rp.set_name_label_visible(false)
	check("RemotePlayer: set_name_label_visible(false) ẩn cả tên và guild", not rp._label.visible and not rp._guild_tag.visible)
	rp.set_name_label_visible(true)
	check("RemotePlayer: set_name_label_visible(true) hiện lại cả tên và guild", rp._label.visible and rp._guild_tag.visible)
	rp.set_guild("", 0)
	check("RemotePlayer: set_guild rỗng thì ẩn GuildTag", not rp._guild_tag.visible)
	rp.queue_free()

func _test_guild_window_ui() -> void:
	var prof := PlayerProfile.new()
	prof.display_name = "KnightVN"
	prof.level = 80
	prof.lead_level = 30
	prof.gold = 50_000_000
	prof.prestige = 500
	prof.fuyuan = 500
	var hub := SocialHub.of(prof)
	hub.guild.create("VietMU", Camp.Type.JUSTICE, null, 7)
	var win := GuildWindow.new(hub)
	add_child(win)
	await get_tree().process_frame
	check("GuildWindow: mở tab Tin tức thành công khi có biểu tượng bang", win._content.get_child_count() > 0)
	win._tab = GuildWindow.Tab.USE
	win._rebuild()
	await get_tree().process_frame
	check("GuildWindow: mở tab Sử dụng chức năng (đổi biểu tượng) thành công", win._content.get_child_count() > 0)
	win.queue_free()
	SocialHub.forget(prof)
