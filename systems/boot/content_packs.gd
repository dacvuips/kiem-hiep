extends Node
## Bản cài qua APK launcher (thư mục launcher/): launcher khởi động game bằng `--main-pack <core.pck>` và truyền
## `++ --kh-content=<thư mục gói>`. Autoload này nạp các gói tài nguyên còn lại (avatar, quái, chiêu, map, âm thanh, đồ)
## ngay trong _init — TRƯỚC khi autoload sau nạp script — nên phải đứng ĐẦU danh sách autoload.
## Chạy từ editor / APK đầy đủ: không có tham số -> không làm gì.

const ARG := "--kh-content="

## Tên các gói đã nạp (để màn hình debug / báo lỗi biết bản cài đang dùng).
var loaded: PackedStringArray = []
var version := 0

func _init() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(ARG):
			dir = arg.substr(ARG.length())
	if dir.is_empty():
		return
	var installed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("installed.json")))
	if not installed is Dictionary:
		push_error("ContentPacks: không đọc được %s/installed.json" % dir)
		return
	version = int(installed.get("version", 0))
	var packs: Array = installed.get("packs", [])
	# Gói đầu (core) đã là main pack. replace_files=false: gói tài nguyên có kèm project.binary/uid_cache/.remap
	# của lúc xuất — không được đè bản của core.
	for i in range(1, packs.size()):
		var file := str((packs[i] as Dictionary).get("file", ""))
		if ProjectSettings.load_resource_pack(dir.path_join(file), false):
			loaded.append(file)
		else:
			push_error("ContentPacks: không nạp được gói " + file)
