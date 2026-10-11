@tool
extends Node

const DEFAULT_PORT := 6970
const SCREENSHOT_UDP_PORT := 6971

var tcp_server: TCPServer
var clients: Array[StreamPeerTCP] = []
var client_buffers: Dictionary = {}
var addr_file_path: String = ""

var debugger_plugin: EditorDebuggerPlugin = null

var auto_stop_active: bool = false
var auto_stop_timeout: float = 0.0

var last_output_length: int = 0
var _cached_output_panel: RichTextLabel = null
var _cached_errors_tree: Tree = null
var _cached_monitors_tree: Tree = null
var _cached_stack_trace_label: RichTextLabel = null
var _cached_stack_trace_label_44: Label = null
var _cached_stack_frames_tree: Tree = null
var _cached_debugger_inspector: Control = null
var _cached_main_inspector: Control = null
var _cached_profiler_tree: Tree = null
var _cached_profiler_spinbox: SpinBox = null
var _cached_profiler_scope_btn: OptionButton = null


static func get_temp_file_path(filename: String) -> String:
	if OS.get_name() == "Windows":
		return OS.get_temp_dir().path_join(filename)
	return "/tmp/" + filename


static func sanitize_project_name(project_dir: String) -> String:
	var path := project_dir.trim_suffix("/").trim_suffix("\\")
	var dirname := path.get_file()
	var sanitized := ""
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9]$")
	for i in range(dirname.length()):
		var ch := dirname.substr(i, 1)
		if regex.search(ch):
			sanitized += ch.to_lower()
		elif not sanitized.is_empty() and not sanitized.ends_with("-"):
			sanitized += "-"
	while sanitized.ends_with("-"):
		sanitized = sanitized.left(sanitized.length() - 1)
	return sanitized if not sanitized.is_empty() else "default"


func start_server(dbg_plugin: EditorDebuggerPlugin) -> void:
	debugger_plugin = dbg_plugin
	tcp_server = TCPServer.new()

	var project_path := ProjectSettings.globalize_path("res://")
	var sanitized := sanitize_project_name(project_path)
	addr_file_path = get_temp_file_path("godot-peek-" + sanitized + ".addr")

	var port := DEFAULT_PORT
	var started := false
	for attempt in range(10):
		if tcp_server.listen(port, "127.0.0.1") == OK:
			started = true
			break
		port += 1

	if not started:
		push_error("GodotPeekPlugin (GDScript): failed to listen on TCP ports 6970-6979")
		return

	var addr_str := "127.0.0.1:%d" % port
	var f := FileAccess.open(addr_file_path, FileAccess.WRITE)
	if f:
		f.store_string(addr_str)
		f.close()

	print("GodotPeekPlugin (GDScript TCP): listening on ", addr_str, " (addr file: ", addr_file_path, ")")


func stop_server() -> void:
	for client in clients:
		client.disconnect_from_host()
	clients.clear()
	client_buffers.clear()
	if tcp_server and tcp_server.is_listening():
		tcp_server.stop()
	if not addr_file_path.is_empty() and FileAccess.file_exists(addr_file_path):
		DirAccess.remove_absolute(addr_file_path)


func _process(delta: float) -> void:
	if auto_stop_active:
		auto_stop_timeout -= delta
		if auto_stop_timeout <= 0.0:
			auto_stop_active = false
			if EditorInterface.is_playing_scene():
				print("GodotPeekPlugin: auto-stopping scene (timeout)")
				EditorInterface.stop_playing_scene()

	if not tcp_server or not tcp_server.is_listening():
		return

	while tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		if peer:
			peer.set_no_delay(true)
			clients.append(peer)
			client_buffers[peer] = ""

	for i in range(clients.size() - 1, -1, -1):
		var peer := clients[i]
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			client_buffers.erase(peer)
			clients.remove_at(i)
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk := peer.get_utf8_string(avail)
			var buf: String = client_buffers.get(peer, "") + chunk
			while true:
				var nl := buf.find("\n")
				if nl == -1:
					break
				var line := buf.substr(0, nl).strip_edges()
				buf = buf.substr(nl + 1)
				if not line.is_empty():
					var resp := _handle_message(line)
					var out_bytes := (resp + "\n").to_utf8_buffer()
					peer.put_data(out_bytes)
			client_buffers[peer] = buf


func _make_result(id: Variant, result_data: Variant) -> String:
	return JSON.stringify({"id": id, "result": result_data})


func _make_error(id: Variant, code: int, message: String) -> String:
	return JSON.stringify({"id": id, "error": {"code": code, "message": message}})


func _handle_message(message: String) -> String:
	var json := JSON.new()
	if json.parse(message) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return '{"id":null,"error":{"code":-32700,"message":"Parse error"}}'

	var req: Dictionary = json.data
	var id: Variant = req.get("id", 0)
	if typeof(id) == TYPE_FLOAT:
		id = int(id)

	if not req.has("method") or typeof(req["method"]) != TYPE_STRING:
		return _make_error(id, -32600, "Invalid request: missing method")

	var method: String = req["method"]
	var params: Dictionary = req.get("params", {}) if typeof(req.get("params")) == TYPE_DICTIONARY else {}

	match method:
		"ping":
			return _make_result(id, {"status": "ok"})
		"run_main_scene":
			return _handle_run_main_scene(id, params)
		"run_scene":
			return _handle_run_scene(id, params)
		"run_current_scene":
			return _handle_run_current_scene(id, params)
		"stop_scene":
			EditorInterface.stop_playing_scene()
			return _make_result(id, {"success": true, "action": "stop_scene"})
		"get_output":
			return _handle_get_output(id, params)
		"get_debugger_errors":
			return _handle_get_debugger_errors(id)
		"get_monitors":
			return _handle_get_monitors(id)
		"get_debugger_stack_trace":
			return _handle_get_debugger_stack_trace(id)
		"get_debugger_locals":
			return _handle_get_debugger_locals(id)
		"get_remote_scene_tree":
			return _handle_get_remote_scene_tree(id, params)
		"get_remote_node_properties":
			return _handle_get_remote_node_properties(id, params)
		"set_breakpoint":
			return _handle_set_breakpoint(id, params)
		"clear_breakpoints":
			if debugger_plugin:
				debugger_plugin.clear_all_breakpoints()
			return _make_result(id, {"success": true})
		"get_debugger_state":
			return _make_result(id, {
				"paused": debugger_plugin.is_paused() if debugger_plugin else false,
				"active": debugger_plugin.is_session_active() if debugger_plugin else false,
				"debuggable": debugger_plugin.is_debuggable() if debugger_plugin else false,
				"is_playing": EditorInterface.is_playing_scene()
			})
		"debug_continue":
			if debugger_plugin:
				debugger_plugin.continue_execution()
			return _make_result(id, {"success": true})
		"debug_step":
			return _handle_debug_step(id, params)
		"debug_break":
			if debugger_plugin:
				debugger_plugin.request_break()
			return _make_result(id, {"success": true})
		"get_screenshot":
			return _handle_get_screenshot(id, params)
		"get_profiler_frame":
			return _handle_get_profiler_frame(id, params)
		"discover_profiler":
			return _make_result(id, {"profiler_controls": [], "debugger_tab_buttons": []})
		_:
			return _make_error(id, -32601, "Method not found: " + method)


func _schedule_auto_stop(params: Dictionary) -> void:
	var timeout := float(params.get("timeout_seconds", 0.0))
	if timeout > 0.0:
		auto_stop_timeout = timeout
		auto_stop_active = true
		print("GodotPeekPlugin: auto-stop scheduled in ", timeout, "s")
	else:
		auto_stop_active = false


func _handle_run_main_scene(id: Variant, params: Dictionary) -> String:
	if EditorInterface.is_playing_scene():
		return _make_error(id, -32000, "A scene is already running. Stop it first with stop_scene.")
	EditorInterface.play_main_scene()
	_schedule_auto_stop(params)
	return _make_result(id, {"success": true, "action": "run_main_scene"})


func _handle_run_scene(id: Variant, params: Dictionary) -> String:
	var scene_path: String = str(params.get("scene_path", ""))
	if scene_path.is_empty():
		return _make_error(id, -32602, "Missing required param: scene_path")
	if EditorInterface.is_playing_scene():
		return _make_error(id, -32000, "A scene is already running. Stop it first with stop_scene.")
	EditorInterface.play_custom_scene(scene_path)
	_schedule_auto_stop(params)
	return _make_result(id, {"success": true, "action": "run_scene", "scene_path": scene_path})


func _handle_run_current_scene(id: Variant, params: Dictionary) -> String:
	if EditorInterface.is_playing_scene():
		return _make_error(id, -32000, "A scene is already running. Stop it first with stop_scene.")
	EditorInterface.play_current_scene()
	_schedule_auto_stop(params)
	return _make_result(id, {"success": true, "action": "run_current_scene"})


func _find_all_by_class(root: Node, cls_name: String) -> Array[Node]:
	var results: Array[Node] = []
	if root.is_class(cls_name):
		results.append(root)
	for i in range(root.get_child_count()):
		results.append_array(_find_all_by_class(root.get_child(i), cls_name))
	return results


func _get_output_panel() -> RichTextLabel:
	if is_instance_valid(_cached_output_panel):
		return _cached_output_panel
	var base := EditorInterface.get_base_control()
	if not base:
		return null
	for node in _find_all_by_class(base, "RichTextLabel"):
		var p := str(node.get_path())
		if p.contains("EditorLog") or (p.contains("EditorBottomPanel") and p.contains("/Output/")):
			_cached_output_panel = node as RichTextLabel
			return _cached_output_panel
	return null


func _get_errors_tree() -> Tree:
	if is_instance_valid(_cached_errors_tree):
		return _cached_errors_tree
	var base := EditorInterface.get_base_control()
	if not base:
		return null
	for node in _find_all_by_class(base, "Tree"):
		var p := str(node.get_path())
		if (p.contains("EditorDebuggerNode") or p.contains("/Debugger/")) and p.contains("/Errors"):
			_cached_errors_tree = node as Tree
			return _cached_errors_tree
	return null


func _get_monitors_tree() -> Tree:
	if is_instance_valid(_cached_monitors_tree):
		return _cached_monitors_tree
	var base := EditorInterface.get_base_control()
	if not base:
		return null
	for node in _find_all_by_class(base, "Tree"):
		var p := str(node.get_path())
		if (p.contains("EditorDebuggerNode") or p.contains("/Debugger/")) and p.contains("/Monitors"):
			_cached_monitors_tree = node as Tree
			return _cached_monitors_tree
	return null


func _handle_get_output(id: Variant, params: Dictionary) -> String:
	var output := _get_output_panel()
	if not output:
		return _make_error(id, -32000, "Output dock not found")
	var new_only := bool(params.get("new_only", false))
	var clear := bool(params.get("clear", false))
	var full_text := output.get_parsed_text()
	var full_length := full_text.length()
	var output_text := ""
	if new_only:
		if last_output_length < full_length:
			output_text = full_text.substr(last_output_length)
	else:
		output_text = full_text
	if clear:
		last_output_length = full_length
	return _make_result(id, {
		"output": output_text,
		"length": output_text.length(),
		"total_length": full_length
	})


func _get_tree_item_text(item: TreeItem, depth: int) -> String:
	var result := ""
	var indent := "  ".repeat(depth)
	var tree := item.get_tree()
	var col_count := tree.get_columns()
	var parts: PackedStringArray = []
	for col in range(col_count):
		var t := item.get_text(col)
		if not t.is_empty():
			parts.append(t)
	if not parts.is_empty():
		result += indent + " | ".join(parts) + "\n"
	var child := item.get_first_child()
	while child:
		result += _get_tree_item_text(child, depth + 1)
		child = child.get_next()
	return result


func _get_tree_text(tree: Tree) -> String:
	var root := tree.get_root()
	if not root:
		return ""
	return _get_tree_item_text(root, 0)


func _handle_get_debugger_errors(id: Variant) -> String:
	var tree := _get_errors_tree()
	if not tree:
		return _make_error(id, -32000, "Debugger Errors tree not found")
	var errors := _get_tree_text(tree)
	return _make_result(id, {"errors": errors, "length": errors.length()})


func _handle_get_monitors(id: Variant) -> String:
	var tree := _get_monitors_tree()
	if not tree:
		return _make_error(id, -32000, "Monitors tree not found")
	var root := tree.get_root()
	if not root:
		return _make_result(id, {"monitors": [], "count": 0})
	var monitors: Array = []
	var group := root.get_first_child()
	while group:
		var group_name := group.get_text(0)
		var metrics: Array = []
		var metric := group.get_first_child()
		while metric:
			metrics.append({"name": metric.get_text(0), "value": metric.get_text(1)})
			metric = metric.get_next()
		monitors.append({"group": group_name, "metrics": metrics})
		group = group.get_next()
	return _make_result(id, {"monitors": monitors, "count": monitors.size()})


func _handle_get_debugger_stack_trace(id: Variant) -> String:
	var base := EditorInterface.get_base_control()
	if not is_instance_valid(_cached_stack_trace_label):
		for node in _find_all_by_class(base, "RichTextLabel"):
			if str(node.get_path()).contains("/Stack Trace/"):
				_cached_stack_trace_label = node as RichTextLabel
				break
	if not is_instance_valid(_cached_stack_frames_tree):
		for node in _find_all_by_class(base, "Tree"):
			if str(node.get_path()).contains("/Stack Trace/"):
				_cached_stack_frames_tree = node as Tree
				break

	var error_msg := _cached_stack_trace_label.get_parsed_text() if is_instance_valid(_cached_stack_trace_label) else ""
	var frames := _get_tree_text(_cached_stack_frames_tree) if is_instance_valid(_cached_stack_frames_tree) else ""
	if error_msg.is_empty() and frames.is_empty():
		return _make_error(id, -32000, "Stack trace not found (is debugger paused?)")
	var combined := error_msg
	if not frames.is_empty():
		if not combined.is_empty():
			combined += "\n\nStack frames:\n"
		combined += frames
	return _make_result(id, {"stack_trace": combined, "length": combined.length()})


func _extract_property_value(node: Node, cls: String) -> String:
	if cls == "EditorPropertyNil":
		return "null"
	if cls == "EditorPropertyInteger" or cls == "EditorPropertyFloat":
		var sliders := _find_all_by_class(node, "EditorSpinSlider")
		if not sliders.is_empty() and sliders[0].has_method("get_value"):
			return str(sliders[0].call("get_value"))
	if cls == "EditorPropertyText":
		var edits := _find_all_by_class(node, "LineEdit")
		if not edits.is_empty():
			return (edits[0] as LineEdit).text
	if cls == "EditorPropertyCheck":
		var boxes := _find_all_by_class(node, "CheckBox")
		if not boxes.is_empty():
			return "true" if (boxes[0] as CheckBox).button_pressed else "false"
	if cls.begins_with("EditorPropertyVector"):
		var sliders := _find_all_by_class(node, "EditorSpinSlider")
		if not sliders.is_empty():
			var vals: PackedStringArray = []
			for s in sliders:
				if s.has_method("get_value"):
					vals.append(str(s.call("get_value")))
			return "(" + ", ".join(vals) + ")"
	var line_edits := _find_all_by_class(node, "LineEdit")
	if not line_edits.is_empty():
		return (line_edits[0] as LineEdit).text
	var buttons := _find_all_by_class(node, "Button")
	if not buttons.is_empty():
		return (buttons[0] as Button).text
	return ""


func _collect_editor_properties(node: Node, properties: Array) -> void:
	var cls := node.get_class()
	if cls.begins_with("EditorProperty"):
		var prop_name := ""
		if node.has_method("get_label"):
			prop_name = str(node.call("get_label"))
		if prop_name.is_empty():
			for lbl in _find_all_by_class(node, "Label"):
				var t := (lbl as Label).text
				if not t.is_empty():
					prop_name = t
					break
		if not prop_name.is_empty():
			properties.append({
				"name": prop_name,
				"value": _extract_property_value(node, cls),
				"type": cls
			})
	for i in range(node.get_child_count()):
		_collect_editor_properties(node.get_child(i), properties)


func _handle_get_debugger_locals(id: Variant) -> String:
	var base := EditorInterface.get_base_control()
	if not is_instance_valid(_cached_debugger_inspector):
		var nodes := _find_all_by_class(base, "EditorDebuggerInspector")
		if not nodes.is_empty():
			_cached_debugger_inspector = nodes[0] as Control
	if not is_instance_valid(_cached_debugger_inspector):
		return _make_error(id, -32000, "EditorDebuggerInspector not found (is debugger paused?)")
	var locals: Array = []
	_collect_editor_properties(_cached_debugger_inspector, locals)
	return _make_result(id, {"locals": locals, "count": locals.size(), "frame_index": -1})


func _get_remote_scene_tree(click_remote: bool) -> Tree:
	var base := EditorInterface.get_base_control()
	if not base:
		return null
	if click_remote:
		for node in _find_all_by_class(base, "Button"):
			var p := str(node.get_path())
			if p.contains("/Scene/"):
				var btn := node as Button
				if btn and btn.text == "Remote":
					if not btn.button_pressed:
						btn.button_pressed = true
						btn.pressed.emit()
					break
	var nodes := _find_all_by_class(base, "EditorDebuggerTree")
	return (nodes[0] as Tree) if not nodes.is_empty() else null


func _get_scene_tree_item_text(item: TreeItem, depth: int, max_depth: int) -> String:
	var result := ""
	var indent := "  ".repeat(depth)
	var node_name := item.get_text(0)
	if not node_name.is_empty():
		var tt := item.get_tooltip_text(0)
		var type_str := ""
		var p_open := tt.find("(")
		if p_open != -1:
			var p_close := tt.find(")", p_open)
			if p_close != -1:
				type_str = tt.substr(p_open + 1, p_close - p_open - 1)
		result += indent + node_name + (" (" + type_str + ")" if not type_str.is_empty() else "") + "\n"
	if max_depth > 0 and depth >= max_depth:
		var count := 0
		var c := item.get_first_child()
		while c:
			count += 1
			c = c.get_next()
		if count > 0:
			result += "  ".repeat(depth + 1) + "(... %d children)\n" % count
		return result
	var child := item.get_first_child()
	while child:
		result += _get_scene_tree_item_text(child, depth + 1, max_depth)
		child = child.get_next()
	return result


func _handle_get_remote_scene_tree(id: Variant, params: Dictionary) -> String:
	var max_depth := int(params.get("max_depth", 0))
	var tree := _get_remote_scene_tree(false)
	var root := tree.get_root() if tree else null
	var has_content := root != null and root.get_child_count() > 0
	var clicked := false
	if not has_content:
		tree = _get_remote_scene_tree(true)
		clicked = true
		root = tree.get_root() if tree else null
		has_content = root != null and root.get_child_count() > 0
	if not tree:
		return _make_error(id, -32000, "Remote scene tree not found (is game running?)")
	if not has_content and clicked:
		return _make_result(id, {"tree": "", "length": 0, "pending": true, "message": "Remote button clicked, retry in ~100ms"})
	if not root or not has_content:
		return _make_error(id, -32000, "Remote scene tree is empty (is game running?)")
	var tree_text := _get_scene_tree_item_text(root, 0, max_depth)
	return _make_result(id, {"tree": tree_text, "length": tree_text.length(), "pending": false})


func _find_tree_item_by_path(root: TreeItem, parts: PackedStringArray) -> TreeItem:
	if parts.is_empty():
		return root
	var current := root
	var start_idx := 1 if parts[0] == root.get_text(0) else 0
	for i in range(start_idx, parts.size()):
		var found := false
		var child := current.get_first_child()
		while child:
			if child.get_text(0) == parts[i]:
				current = child
				found = true
				break
			child = child.get_next()
		if not found:
			return null
	return current


func _handle_get_remote_node_properties(id: Variant, params: Dictionary) -> String:
	var node_path := str(params.get("node_path", ""))
	if node_path.is_empty():
		return _make_error(id, -32602, "Missing required param: node_path")
	var tree := _get_remote_scene_tree(true)
	if not tree:
		return _make_error(id, -32000, "Remote scene tree not found (is game running?)")
	var root := tree.get_root()
	if not root or root.get_child_count() == 0:
		return _make_result(id, {"node_path": node_path, "properties": [], "count": 0, "pending": true, "message": "Remote tree populating"})

	var base := EditorInterface.get_base_control()
	if not is_instance_valid(_cached_main_inspector):
		for node in _find_all_by_class(base, "EditorInspector"):
			var p := str(node.get_path())
			if p.contains("DockSlotRightUL/Inspector/") or p.contains("DockSlotRightBL/Inspector/"):
				_cached_main_inspector = node as Control
				break
	if not is_instance_valid(_cached_main_inspector):
		return _make_error(id, -32000, "Main inspector not found")

	var parts := node_path.trim_prefix("/").split("/", false)
	var target := _find_tree_item_by_path(root, parts)
	if not target:
		return _make_error(id, -32000, "Node not found in remote tree: " + node_path)

	if tree.get_selected() != target:
		var meta: Variant = target.get_metadata(0)
		if meta != null:
			tree.set_selected(target, 0)
			if tree.has_signal("objects_selected"):
				tree.emit_signal("objects_selected", PackedInt64Array([int(meta)]), 0)
			elif tree.has_signal("object_selected"):
				tree.emit_signal("object_selected", int(meta), 0)
		return _make_result(id, {"node_path": node_path, "properties": [], "count": 0, "pending": true, "message": "Inspection triggered"})

	var props: Array = []
	_collect_editor_properties(_cached_main_inspector, props)
	if props.is_empty():
		return _make_result(id, {"node_path": node_path, "properties": [], "count": 0, "pending": true, "message": "Inspector loading"})
	return _make_result(id, {"node_path": node_path, "properties": props, "count": props.size(), "pending": false})


func _handle_set_breakpoint(id: Variant, params: Dictionary) -> String:
	var path := str(params.get("path", ""))
	if path.is_empty() or not params.has("line"):
		return _make_error(id, -32602, "Missing required param: path or line")
	var line := int(params["line"])
	var enabled := bool(params.get("enabled", true))
	if debugger_plugin:
		debugger_plugin.set_breakpoint_in_editor(path, line, enabled)
	return _make_result(id, {"success": true, "path": path, "line": line, "enabled": enabled})


func _handle_debug_step(id: Variant, params: Dictionary) -> String:
	var mode := str(params.get("mode", "over"))
	if not debugger_plugin:
		return _make_error(id, -32000, "Debugger plugin not initialized")
	match mode:
		"into":
			debugger_plugin.step_into()
		"over":
			debugger_plugin.step_over()
		"out":
			debugger_plugin.step_out()
		_:
			return _make_error(id, -32602, "Invalid mode: " + mode)
	return _make_result(id, {"success": true, "mode": mode})


func _handle_get_screenshot(id: Variant, params: Dictionary) -> String:
	var target := str(params.get("target", ""))
	if target == "editor":
		return _capture_editor_screenshot(id)
	elif target == "game":
		return _capture_game_screenshot(id)
	return _make_error(id, -32602, "Invalid target: " + target)


func _capture_editor_screenshot(id: Variant) -> String:
	var vp_2d := EditorInterface.get_editor_viewport_2d()
	var vp_3d := EditorInterface.get_editor_viewport_3d(0)
	var img_2d: Image = vp_2d.get_texture().get_image() if vp_2d and vp_2d.size.x > 10 and vp_2d.size.y > 10 and vp_2d.get_texture() else null
	var img_3d: Image = vp_3d.get_texture().get_image() if vp_3d and vp_3d.size.x > 10 and vp_3d.size.y > 10 and vp_3d.get_texture() else null

	var combined: Image = null
	var width := 0
	var height := 0
	if img_2d and img_3d:
		img_2d.convert(Image.FORMAT_RGBA8)
		img_3d.convert(Image.FORMAT_RGBA8)
		width = img_2d.get_width() + img_3d.get_width()
		height = maxi(img_2d.get_height(), img_3d.get_height())
		combined = Image.create(width, height, false, Image.FORMAT_RGBA8)
		combined.blit_rect(img_2d, Rect2i(Vector2i.ZERO, img_2d.get_size()), Vector2i.ZERO)
		combined.blit_rect(img_3d, Rect2i(Vector2i.ZERO, img_3d.get_size()), Vector2i(img_2d.get_width(), 0))
	elif img_2d:
		combined = img_2d
		width = img_2d.get_width()
		height = img_2d.get_height()
	elif img_3d:
		combined = img_3d
		width = img_3d.get_width()
		height = img_3d.get_height()
	else:
		return _make_error(id, -32000, "No editor viewports available")

	var save_path := get_temp_file_path("godot_peek_editor_screenshot.png")
	if combined.save_png(save_path) != OK:
		return _make_error(id, -32000, "Failed to save screenshot")
	return _make_result(id, {"path": save_path, "target": "editor", "width": width, "height": height})


func _capture_game_screenshot(id: Variant) -> String:
	if not EditorInterface.is_playing_scene():
		return _make_error(id, -32000, "Game is not running")
	var udp := PacketPeerUDP.new()
	if udp.set_dest_address("127.0.0.1", SCREENSHOT_UDP_PORT) != OK:
		return _make_error(id, -32000, "Failed to set UDP destination")
	var req_buf := JSON.stringify({"cmd": "screenshot"}).to_utf8_buffer()
	if udp.put_packet(req_buf) != OK:
		return _make_error(id, -32000, "Failed to send UDP request")

	for _attempt in range(20):
		OS.delay_msec(50)
		if udp.get_available_packet_count() > 0:
			var resp_str := udp.get_packet().get_string_from_utf8()
			var json := JSON.new()
			if json.parse(resp_str) != OK or typeof(json.data) != TYPE_DICTIONARY:
				return _make_error(id, -32000, "Invalid response from screenshot listener")
			var resp: Dictionary = json.data
			if resp.has("error"):
				return _make_error(id, -32000, "Screenshot listener error: " + str(resp["error"]))
			return _make_result(id, {
				"path": resp.get("path", get_temp_file_path("godot_peek_game_screenshot.png")),
				"target": "game",
				"width": int(resp.get("width", 0)),
				"height": int(resp.get("height", 0))
			})
	return _make_error(id, -32000, "Timeout waiting for game screenshot")


func _collect_profiler_tree_item(items: Array, item: TreeItem, depth: int) -> void:
	if not item:
		return
	var entry := {
		"depth": depth,
		"function": item.get_text(0),
		"time_percent": item.get_text(1),
		"self_time": item.get_text(2),
		"total_time": item.get_text(3),
		"calls": item.get_text(4)
	}
	var col_count := item.get_tree().get_columns()
	if col_count > 5:
		var extra: Array = []
		for c in range(5, col_count):
			extra.append(item.get_text(c))
		entry["extra_columns"] = extra
	items.append(entry)
	var child := item.get_first_child()
	while child:
		_collect_profiler_tree_item(items, child, depth + 1)
		child = child.get_next()


func _handle_get_profiler_frame(id: Variant, params: Dictionary) -> String:
	if not params.has("frame_number"):
		return _make_error(id, -32602, "Missing required param: frame_number")
	var frame_number := int(params["frame_number"])
	var base := EditorInterface.get_base_control()
	if not is_instance_valid(_cached_profiler_tree):
		for node in _find_all_by_class(base, "Tree"):
			if str(node.get_path()).contains("/Profiler/"):
				_cached_profiler_tree = node as Tree
				break
	if not is_instance_valid(_cached_profiler_spinbox):
		for node in _find_all_by_class(base, "SpinBox"):
			if str(node.get_path()).contains("/Profiler/"):
				_cached_profiler_spinbox = node as SpinBox
				break
	if not is_instance_valid(_cached_profiler_tree):
		return _make_error(id, -32000, "Profiler tree not found")
	if is_instance_valid(_cached_profiler_spinbox):
		var max_val := _cached_profiler_spinbox.max_value
		if max_val <= 0:
			return _make_error(id, -32000, "No profiler frames collected")
		frame_number = clampi(frame_number, 0, int(max_val))
		_cached_profiler_spinbox.value = frame_number
		OS.delay_msec(50)

	var headers: Array = []
	for c in range(_cached_profiler_tree.get_columns()):
		var title := _cached_profiler_tree.get_column_title(c)
		headers.append(title if not title.is_empty() else "col_%d" % c)

	var items: Array = []
	var root := _cached_profiler_tree.get_root()
	if root:
		var child := root.get_first_child()
		while child:
			_collect_profiler_tree_item(items, child, 0)
			child = child.get_next()

	return _make_result(id, {
		"frame_number": frame_number,
		"frame_max": _cached_profiler_spinbox.max_value if is_instance_valid(_cached_profiler_spinbox) else 0.0,
		"columns": headers,
		"items": items,
		"count": items.size()
	})

