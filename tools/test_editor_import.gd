@tool
extends SceneTree

func _init() -> void:
	print('In editor tool script!')
	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		print('Reimporting files...')
		efs.reimport_files(['res://ui/social/telegram_qr.png'])
		print('Reimported!')
	else:
		print('efs is null')
	quit()
