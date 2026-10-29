extends Node

func _ready() -> void:
	print("=== TEST: Market, Compound & Ranking Windows Localization ===")
	var profile := PlayerProfile.new()
	profile.display_name = "TestPlayer"
	profile.gold = 100000
	profile.xu = 500
	profile.jade = 100

	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	assert(loc_mgr != null, "LocalizationManager must exist")

	for target_lang in ["zh", "en", "ja", "vi"]:
		loc_mgr.set_locale(target_lang, false)
		print("\n--- Testing locale: %s ---" % target_lang)

		# 1. Market Window
		var market := MarketWindow.new(SocialHub.of(profile))
		add_child(market)
		print("Market Title: ", market.title_label.text)
		assert(not market.title_label.text.is_empty())
		print("Market Tab 0: ", market._tab_buttons[0].text)
		print("Market Tab 1: ", market._tab_buttons[1].text)
		print("Market Tab 2: ", market._tab_buttons[2].text)
		print("Market Filter Cat (item 0): ", market._f_cat.get_item_text(0))
		print("Market Filter Series (item 0): ", market._f_series.get_item_text(0))

		# Disconnected message test
		market._say(tr("Chưa kết nối tới máy chủ game (hoặc đang kết nối lại)..."), false)
		var banner_label: Label = market._msg.get_child(0) as Label
		print("Market Disconnect msg: ", banner_label.text)

		if target_lang == "zh":
			assert(market.title_label.text == "交易", "Expected '交易', got %s" % market.title_label.text)
			assert(market._tab_buttons[0].text == "交易行", "Expected '交易行', got %s" % market._tab_buttons[0].text)
			assert(market._tab_buttons[1].text == "我的摊位", "Expected '我的摊位', got %s" % market._tab_buttons[1].text)
			assert(market._f_cat.get_item_text(0) == "类型", "Expected '类型', got %s" % market._f_cat.get_item_text(0))
			assert(banner_label.text == "未连接至游戏服务器（或正在重连）...", "Expected zh disconnect msg, got %s" % banner_label.text)
		market.queue_free()

		# 2. Compound Window
		var compound := CompoundWindow.new()
		compound._profile = profile
		add_child(compound)
		print("Compound Title: ", compound.title_label.text)
		print("Compound Tab 0: ", compound._tab_buttons[0].text)
		print("Compound Tab 1: ", compound._tab_buttons[1].text)
		print("Compound Tab 2: ", compound._tab_buttons[2].text)
		print("Compound Tab 3: ", compound._tab_buttons[3].text)
		print("Compound Tab 4: ", compound._tab_buttons[4].text)
		print("Compound Action Button: ", compound._action_button.text)
		print("Compound Grid Title: ", compound._grid_title.text)
		print("Compound Rule Desc: \n", compound._tab_rules_text().substr(0, 80))

		if target_lang == "zh":
			assert(compound.title_label.text == "打造", "Expected '打造', got %s" % compound.title_label.text)
			assert(compound._tab_buttons[0].text == "提炼 ▼", "Expected '提炼 ▼', got %s" % compound._tab_buttons[0].text)
			assert(compound._tab_buttons[1].text == "吸附", "Expected '吸附', got %s" % compound._tab_buttons[1].text)
			assert(compound._tab_buttons[2].text == "打造", "Expected '打造', got %s" % compound._tab_buttons[2].text)
			assert(compound._tab_buttons[3].text == "镶嵌", "Expected '镶嵌', got %s" % compound._tab_buttons[3].text)
			assert(compound._tab_buttons[4].text == "图谱", "Expected '图谱', got %s" % compound._tab_buttons[4].text)
			assert(compound._grid_title.text.contains("背包"), "Expected '背包' in grid title, got %s" % compound._grid_title.text)
			assert(compound._tab_rules_text().contains("所需材料:"), "Expected '所需材料:' in rules text, got %s" % compound._tab_rules_text())
		compound.queue_free()

		# 3. Guild Window Online label test
		var guild_win := GuildWindow.new(SocialHub.of(profile))
		add_child(guild_win)
		guild_win._process(0.0)
		print("Guild Online Label: ", guild_win._online_label.text)
		if target_lang == "zh":
			assert(guild_win._online_label.text == "已在线 0 小时 00 分", "Expected '已在线 0 小时 00 分', got %s" % guild_win._online_label.text)
		guild_win.queue_free()

		# 4. Chat Panel test
		ChatPanel.history.clear()
		var chat_panel := ChatPanel.open(self)
		if not chat_panel.is_node_ready():
			chat_panel._ready()
		print("Chat Tab World: ", chat_panel._tabs[ChatServer.WORLD].text)
		print("Chat Tab Guild: ", chat_panel._tabs[ChatServer.GUILD].text)
		print("Chat Tab Private: ", chat_panel._tabs[ChatServer.PRIVATE].text)
		print("Chat Input Placeholder: ", chat_panel._input.placeholder_text)
		if target_lang == "zh":
			assert(chat_panel._tabs[ChatServer.WORLD].text == "世界", "Expected '世界', got %s" % chat_panel._tabs[ChatServer.WORLD].text)
			assert(chat_panel._tabs[ChatServer.GUILD].text == "帮会", "Expected '帮会', got %s" % chat_panel._tabs[ChatServer.GUILD].text)
			assert(chat_panel._tabs[ChatServer.PRIVATE].text == "私聊", "Expected '私聊', got %s" % chat_panel._tabs[ChatServer.PRIVATE].text)
		chat_panel.close()

		# 3. Ranking Window
		var ranking := RankingWindow.new(profile)
		add_child(ranking)
		print("Ranking Title: ", ranking.title_label.text)
		print("Ranking Tab 0: ", ranking._tab_buttons[0].text)
		print("Ranking Tab 1: ", ranking._tab_buttons[1].text)
		print("Ranking Tab 2: ", ranking._tab_buttons[2].text)
		print("Ranking Tab 3: ", ranking._tab_buttons[3].text)

		if target_lang == "zh":
			assert(ranking.title_label.text == "排行榜", "Expected '排行榜', got %s" % ranking.title_label.text)
			assert(ranking._tab_buttons[0].text == "高手", "Expected '高手', got %s" % ranking._tab_buttons[0].text)
			assert(ranking._tab_buttons[1].text == "富豪", "Expected '富豪', got %s" % ranking._tab_buttons[1].text)
			assert(ranking._tab_buttons[2].text == "武林PK", "Expected '武林PK', got %s" % ranking._tab_buttons[2].text)
			assert(ranking._tab_buttons[3].text == "门派", "Expected '门派', got %s" % ranking._tab_buttons[3].text)
		ranking.queue_free()

	loc_mgr.set_locale("vi", true)
	print("\n=== ALL MARKET, COMPOUND & RANKING LOCALIZATION TESTS PASSED! ===")
	get_tree().quit(0)
