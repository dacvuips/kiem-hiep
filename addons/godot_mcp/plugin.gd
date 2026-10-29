@tool
extends EditorPlugin

const AUTOLOAD_NAME := "PeekRuntimeHelper"
const AUTOLOAD_PATH := "res://addons/godot_mcp/peek_runtime_helper.gd"
const PeekDebuggerPluginScript := preload("res://addons/godot_mcp/peek_debugger_plugin.gd")
const PeekEditorServerScript := preload("res://addons/godot_mcp/peek_editor_server.gd")

var _fallback_debugger_plugin: EditorDebuggerPlugin = null
var _fallback_server: Node = null


func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return

	# add autoload if not present
	var setting := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, "*" + AUTOLOAD_PATH)
		ProjectSettings.save()
		print("[GodotPeek] Added %s autoload" % AUTOLOAD_NAME)

	# If native C++ GDExtension (GodotPeekPlugin) is not loaded (e.g. on Windows),
	# automatically start the pure-GDScript TCP Editor Server and Debugger Plugin.
	if not ClassDB.class_exists("GodotPeekPlugin"):
		_fallback_debugger_plugin = PeekDebuggerPluginScript.new()
		add_debugger_plugin(_fallback_debugger_plugin)
		_fallback_server = PeekEditorServerScript.new()
		add_child(_fallback_server)
		_fallback_server.start_server(_fallback_debugger_plugin)


func _exit_tree() -> void:
	if _fallback_server:
		_fallback_server.stop_server()
		_fallback_server.queue_free()
		_fallback_server = null
	if _fallback_debugger_plugin:
		remove_debugger_plugin(_fallback_debugger_plugin)
		_fallback_debugger_plugin = null
