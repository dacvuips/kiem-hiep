extends SceneTree

func _init() -> void:
	print("--- TEST PHONG LANG DO ---")
	var entry := PhongLangDoChallenge.map_entry()
	print("Map entry: ", entry)
	assert(entry["id"] in [336, 337])
	assert(entry["phong_lang_do"] == true)

	var p := PlayerProfile.new()
	p.display_name = "TestPlayer"
	p.level = 40
	p.gold = 100000

	# Test level requirement
	var reason := PhongLangDoChallenge.check_entry(p)
	print("Level 40 reason: ", reason)
	assert(reason != "")

	# Level 50 but not enough money or item
	p.level = 50
	p.gold = 1000
	reason = PhongLangDoChallenge.check_entry(p)
	print("Not enough money/item reason: ", reason)
	assert(reason != "")

	# With 20k gold
	p.gold = 25000
	reason = PhongLangDoChallenge.check_entry(p)
	print("Eligible with gold reason: '", reason, "'")
	assert(reason == "")

	# Test pay entry
	var ok := PhongLangDoChallenge.pay_entry(p)
	assert(ok == true)
	assert(p.gold == 5000)
	print("Paid gold successfully. Remaining gold: ", p.gold)
	print("Runs today: ", PhongLangDoChallenge.runs_today(p))
	assert(PhongLangDoChallenge.runs_today(p) == 1)

	# Test MapSelectWindow instantiation
	var win := MapSelectWindow.new(p)
	print("MapSelectWindow created successfully!")
	win._select_tab(2)
	print("Tab 2 (Ải) loaded successfully!")
	
	print("ALL PHONG LANG DO TESTS PASSED!")
	quit(0)
