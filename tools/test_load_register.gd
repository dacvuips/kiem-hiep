extends SceneTree

func _init():
	print("[*] Testing load res://ui/account/Register.tscn")
	var res = ResourceLoader.load("res://ui/account/Register.tscn")
	if res:
		print("[OK] Register.tscn loaded successfully: ", res)
		var inst = res.instantiate()
		print("[OK] Instantiated: ", inst)
	else:
		print("[ERROR] Failed to load Register.tscn!")
	quit()
