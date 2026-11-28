extends Node

func _ready() -> void:
	print("--- TEST OFFLINE CHARACTER DELETION STARTED ---")
	var sm = get_node_or_null("/root/SaveManager")
	var gmm = load("res://systems/game_mode/game_mode_manager.gd")
	var gm = get_node_or_null("/root/GameManager")

	assert(sm != null, "SaveManager must exist")
	assert(gmm != null, "GameModeManager script must exist")

	# 1. Switch to OFFLINE mode
	gmm.set_mode(gmm.Mode.OFFLINE)
	assert(gmm.is_offline(), "GameModeManager must be in offline mode")

	# 2. Create and save an offline profile
	var off_prof = PlayerProfile.new()
	off_prof.display_name = "OfflineWarrior"
	off_prof.level = 15
	off_prof.sect_id = "thieu_lam"
	sm.save_profile(off_prof)

	assert(sm.has_profile(), "Offline profile should exist after save")
	var loaded = sm.load_profile()
	assert(loaded != null and loaded.display_name == "OfflineWarrior", "Should load saved offline profile")
	print("Offline profile saved and verified: %s" % loaded.display_name)

	# 3. Create an online profile under the same account to verify separation
	gmm.set_mode(gmm.Mode.ONLINE)
	var on_prof = PlayerProfile.new()
	on_prof.display_name = "OnlineHero"
	on_prof.level = 50
	on_prof.sect_id = "vo_dang"
	sm.save_profile(on_prof)
	assert(not sm.has_profile() and not sm._has_any_online_file(), "Online must not keep any profile on this machine")
	print("Online profile not stored locally (server only)")

	# 4. Switch back to OFFLINE and delete offline profile
	gmm.set_mode(gmm.Mode.OFFLINE)
	assert(sm.has_profile(), "Offline profile should still exist before deletion")
	var deleted = sm.delete_offline_profile()
	assert(deleted, "delete_offline_profile should return true")
	assert(not sm.has_profile(), "Offline profile should no longer exist after deletion")
	print("Offline profile deleted successfully!")

	# 5. Verify that ONLINE profile was NOT affected or touched
	gmm.set_mode(gmm.Mode.ONLINE)
	assert(sm.load_profile() == null, "Online never reads a profile from this machine")

	print("--- TEST OFFLINE CHARACTER DELETION PASSED 100% ---")
	get_tree().quit(0)
