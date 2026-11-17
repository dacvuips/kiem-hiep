extends Node2D
class_name PubgZoneOverlay
## Hiển thị VÒNG BO PUBG trong map (dữ liệu ở PubgManager):
##   - Ngoài vòng bo TỐI DẦN (càng xa mép bo càng tối, bo càng về sau càng tối) — vẽ bằng shader 1 tấm phủ đúng khung camera,
##     nên map to cỡ nào cũng chỉ tốn 1 lần vẽ.
##   - Viền xanh = vòng an toàn hiện tại, viền trắng = vòng sắp co tới.
##   - Thời tiết Sơn Trang (FarmHud.WeatherVFX) phủ màn hình, đổi mỗi khi 1 lần bo kết thúc.
##   - Dòng trạng thái bo + cảnh báo đứng ngoài bo (mất bao nhiêu máu / giây) trên HUD.
## Gắn vào VltkWorld khi trận PUBG bắt đầu (VltkWorld._process), tự gỡ khi trận kết thúc.

const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 zone_center;
uniform float zone_radius;
uniform vec2 next_center;
uniform float next_radius;
uniform float fade_dist = 900.0;
uniform float max_dark = 0.55;
uniform float line_w = 4.0;
uniform float show_next = 1.0;
uniform vec2 box_center;
uniform vec2 box_half;
varying vec2 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	// vùng an toàn = vòng tròn ∩ khung chơi (khoảng cách có dấu: âm = trong vùng)
	vec2 q = abs(world_pos - box_center) - box_half;
	float d_box = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float d = max(distance(world_pos, zone_center) - zone_radius, d_box);
	float dark = smoothstep(0.0, fade_dist, d) * max_dark;
	vec4 col = vec4(0.02, 0.0, 0.06, dark);
	// viền vòng an toàn hiện tại (xanh)
	float ring = 1.0 - smoothstep(0.0, line_w, abs(d));
	col = mix(col, vec4(0.25, 0.75, 1.0, 0.95), ring);
	// viền vòng kế tiếp (trắng, mảnh)
	float dn = abs(distance(world_pos, next_center) - next_radius);
	float ring2 = (1.0 - smoothstep(0.0, line_w * 0.6, dn)) * show_next;
	col = mix(col, vec4(1.0, 1.0, 1.0, 0.85), ring2);
	COLOR = col;
}
"""

## Thoại báo trước khi bo co (giọng nam trầm, tools/generate_pubg_zone_voices.py)
const ZONE_VOICE := "res://audio/sfx/pubg/zone_warn_%d.mp3"

var _rect: ColorRect
var _mat: ShaderMaterial
var _weather_vfx: Control
var _shown_weather := -1
var _hud: Label
var _warn: Label
var _announce: Label
var _announce_t := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4000                     ## trên mọi thứ trong map, dưới UI (UI là CanvasLayer riêng)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	_build_screen_ui()
	PubgManager.zone_event = _on_zone_event

func _exit_tree() -> void:
	for n in [_weather_vfx, _hud, _warn, _announce]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	if PubgManager.zone_event == Callable(self, "_on_zone_event"):
		PubgManager.zone_event = Callable()

## Thời tiết + chữ HUD nằm trong CanvasLayer "UI" của Main (dưới các khung khác), không thì tự tạo 1 lớp.
func _build_screen_ui() -> void:
	var ui: Node = get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene != null else null
	if ui == null:
		var layer := CanvasLayer.new()
		layer.layer = 1
		add_child(layer)
		ui = layer
	var vfx_script: GDScript = load("res://ui/son_trang/farm_hud.gd")
	_weather_vfx = vfx_script.WeatherVFX.new()
	_weather_vfx.name = "PubgWeatherVFX"
	ui.add_child(_weather_vfx)
	ui.move_child(_weather_vfx, 0)

	_hud = _make_label(16, Color(0.75, 0.92, 1.0))
	_hud.position = Vector2(0, 92)
	ui.add_child(_hud)
	_warn = _make_label(18, Color(1.0, 0.35, 0.3))
	_warn.position = Vector2(0, 118)
	ui.add_child(_warn)
	_announce = _make_label(24, Color(1.0, 0.86, 0.3))
	_announce.position = Vector2(0, 200)
	ui.add_child(_announce)

func _make_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _process(delta: float) -> void:
	if not PubgManager.is_active:
		queue_free()
		return
	_update_shader()
	_update_weather()
	_update_hud(delta)

## Tấm phủ đúng khung camera (toạ độ thế giới), shader tự tính tối/viền theo toạ độ thế giới.
func _update_shader() -> void:
	var xf := get_viewport().get_canvas_transform()
	var inv := xf.affine_inverse()
	var vp := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vp
	var top_left := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	_rect.global_position = top_left - Vector2(8, 8)
	_rect.size = (b - a).abs() + Vector2(16, 16)
	var zoom := maxf(0.01, xf.get_scale().x)
	var phase := PubgManager.zone_index
	var box := PubgManager.fixed_outer_boundary
	if not box.has_area():
		box = Rect2(PubgManager.zone_center - Vector2.ONE * 1e7, Vector2.ONE * 2e7)
	_mat.set_shader_parameter("box_center", box.get_center())
	_mat.set_shader_parameter("box_half", box.size * 0.5)
	_mat.set_shader_parameter("zone_center", PubgManager.zone_center)
	_mat.set_shader_parameter("zone_radius", PubgManager.zone_radius)
	_mat.set_shader_parameter("next_center", PubgManager.zone_next_center)
	_mat.set_shader_parameter("next_radius", PubgManager.zone_next_radius)
	_mat.set_shader_parameter("show_next", 1.0 if PubgManager.zone_index < PubgManager.ZONE_COUNT else 0.0)
	_mat.set_shader_parameter("line_w", 3.0 / zoom)
	_mat.set_shader_parameter("fade_dist", 900.0)
	_mat.set_shader_parameter("max_dark", minf(0.85, 0.5 + 0.07 * float(phase)))

func _update_weather() -> void:
	if _weather_vfx != null and is_instance_valid(_weather_vfx) and _shown_weather != PubgManager.weather:
		_shown_weather = PubgManager.weather
		_weather_vfx.update_weather(_shown_weather)

func _update_hud(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	for l in [_hud, _warn, _announce]:
		if l != null and is_instance_valid(l):
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.position.x = 80.0
			l.size = Vector2(vp_w - 160.0, 30)
	if _hud != null and is_instance_valid(_hud):
		_hud.text = ""   ## đồng hồ bo đã hiện ngay dưới thanh Sinh lực (TopStatusBar)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if _warn != null and is_instance_valid(_warn):
		var dmg := 0.0
		if p != null:
			var mh: float = float(p.get("max_health")) if p.get("max_health") != null else 1000.0
			dmg = PubgManager.zone_damage_for(mh, p.global_position + Vector2(0, 30))
		_warn.text = ("⚠ Bạn đang ở NGOÀI VÒNG BO! -%d máu / giây — chạy vào vòng xanh" % int(dmg)) if dmg > 0.0 else ""
	if _announce != null and is_instance_valid(_announce):
		_announce_t = maxf(0.0, _announce_t - delta)
		_announce.modulate.a = clampf(_announce_t, 0.0, 1.0)

## "⭕ Bo 1/5 — co sau 07:59 | ☀️ Nắng Đẹp"
static func zone_status_text() -> String:
	var t := maxi(0, int(ceil(PubgManager.zone_timer)))
	var mmss := "%02d:%02d" % [t / 60, t % 60]
	var w_info := FarmTimeSystem.get_weather_info(PubgManager.weather)
	var w := "%s %s" % [str(w_info.get("icon", "")), str(w_info.get("name", ""))]
	if PubgManager.zone_index >= PubgManager.ZONE_COUNT:
		return "⭕ Vòng bo cuối — chỉ còn 1 chấm | %s" % w
	var n := PubgManager.zone_index + 1
	if PubgManager.zone_shrinking:
		return "⭕ Bo %d/%d đang co — %s | %s" % [n, PubgManager.ZONE_COUNT, mmss, w]
	return "⭕ Bo %d/%d co sau %s | %s" % [n, PubgManager.ZONE_COUNT, mmss, w]

func _on_zone_event(ev: String) -> void:
	var msg := ""
	if ev.begins_with("warn_"):
		var sec := int(ev.trim_prefix("warn_"))
		msg = "⚠ Hiệp khách lưu ý: vòng bo sẽ thu hẹp lại sau %d giây nữa, hãy nhanh chóng di chuyển vào trong vòng bo ngay!" % sec
		play_voice(ZONE_VOICE % sec)
	match ev:
		"shrink_start":
			msg = "⭕ Vòng bo %d/%d bắt đầu thu hẹp!" % [PubgManager.zone_index + 1, PubgManager.ZONE_COUNT]
		"shrink_end", "final":
			var w_info := FarmTimeSystem.get_weather_info(PubgManager.weather)
			var w := "%s %s" % [str(w_info.get("icon", "")), str(w_info.get("name", ""))]
			if ev == "final":
				msg = "⭕ Vòng bo cuối cùng: chỉ còn 1 chấm! Thời tiết: %s" % w
			else:
				msg = "⭕ Bo %d/%d đã co xong — Thời tiết đổi: %s" % [PubgManager.zone_index, PubgManager.ZONE_COUNT, w]
	if msg == "":
		return
	if _announce != null and is_instance_valid(_announce):
		_announce.text = msg
		_announce_t = 6.0 if ev.begins_with("warn_") else 4.0
	ChatBox.push_system("[color=#7fd4ff][PUBG][/color] " + msg)

## Phát thoại mp3 (đọc thẳng byte nếu chưa import, như thoại Sơn Trang). Trả về stream đã phát (null nếu thiếu file).
static func play_voice(path: String) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			stream = res
	if stream == null and FileAccess.file_exists(path):
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		stream = mp3
	if stream != null and SfxManager != null:
		SfxManager.play_ui(stream, 2.0)
	return stream
