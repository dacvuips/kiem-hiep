@tool
extends EditorScript

func _run():
	print("Running editor script...")
	var fs = EditorInterface.get_resource_filesystem()
	if fs:
		print("Scanning filesystem...")
		fs.scan()
		fs.reimport_files(["res://ui/login/logo.png", "res://art/logo.png", "res://download/art/logo.png"])
		print("Reimport called!")
	else:
		print("No EditorInterface filesystem")
