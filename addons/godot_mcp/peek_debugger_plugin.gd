@tool
extends EditorDebuggerPlugin

var current_session_id: int = -1
var session_valid: bool = false
var cached_breakpoints: Array[Dictionary] = []


func _setup_session(session_id: int) -> void:
	current_session_id = session_id
	session_valid = true
	var session := get_session(session_id)
	if session:
		_apply_cached_breakpoints(session)


func _has_capture(capture: String) -> bool:
	return capture == "godot_peek"


func _capture(message: String, _data: Array, _session_id: int) -> bool:
	return message.begins_with("godot_peek:")


func get_current_session() -> EditorDebuggerSession:
	if not session_valid or current_session_id < 0:
		return null
	return get_session(current_session_id)


func _apply_cached_breakpoints(session: EditorDebuggerSession) -> void:
	for bp in cached_breakpoints:
		if bp.get("enabled", false):
			session.set_breakpoint(bp["path"], bp["line"], true)


func set_breakpoint_in_editor(path: String, line: int, enabled: bool) -> void:
	for i in range(cached_breakpoints.size() - 1, -1, -1):
		if cached_breakpoints[i]["path"] == path and cached_breakpoints[i]["line"] == line:
			cached_breakpoints.remove_at(i)

	if enabled:
		cached_breakpoints.append({"path": path, "line": line, "enabled": enabled})

	var script := load(path) as Script
	if not script:
		print("GodotPeek: set_breakpoint failed - could not load script: ", path)
		return

	EditorInterface.edit_script(script, line, 0, false)
	var script_editor := EditorInterface.get_script_editor()
	if not script_editor:
		return

	var editor_base := script_editor.get_current_editor()
	if not editor_base:
		return

	var base_control := editor_base.get_base_editor()
	if base_control is CodeEdit:
		(base_control as CodeEdit).set_line_as_breakpoint(line - 1, enabled)


func clear_all_breakpoints() -> void:
	var copy := cached_breakpoints.duplicate()
	for bp in copy:
		set_breakpoint_in_editor(bp["path"], bp["line"], false)
	cached_breakpoints.clear()


func is_paused() -> bool:
	var session := get_current_session()
	return session.is_breaked() if session else false


func is_session_active() -> bool:
	var session := get_current_session()
	return session.is_active() if session else false


func is_debuggable() -> bool:
	var session := get_current_session()
	return session.is_debuggable() if session else false


func step_into() -> void:
	var session := get_current_session()
	if session:
		session.send_message("step", [])


func step_over() -> void:
	var session := get_current_session()
	if session:
		session.send_message("next", [])


func step_out() -> void:
	var session := get_current_session()
	if session:
		session.send_message("out", [])


func continue_execution() -> void:
	var session := get_current_session()
	if session:
		session.send_message("continue", [])


func request_break() -> void:
	var session := get_current_session()
	if session:
		session.send_message("break", [])

