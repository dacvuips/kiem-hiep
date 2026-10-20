@tool
extends EditorScript

func _run() -> void:
	print('Inside EditorScript _run')
	var efs := get_editor_interface().get_resource_filesystem()
	if efs:
		efs.reimport_files(['res://ui/social/telegram_qr.png'])
		print('REIMPORT_DONE')
	else:
		print('efs is null')
