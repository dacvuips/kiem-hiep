extends SceneTree

func _init() -> void:
	print("--- Checking fonts ---")
	var theme: Theme = load("res://assets/fonts/default_theme.tres")
	print("default_font: ", theme.default_font)
	var sym_font: Font = load("res://assets/fonts/symbol_fallback.ttf")
	print("sym_font: ", sym_font)
	
	var chars := ["▸", "▾", "▲", "▼", "⇄", "∞", "✕", "⚙", "🎭", "🪙", "🧰", "🔒", "🎒", "🚩", "👑"]
	for ch in chars:
		var cp = ch.unicode_at(0)
		var sym_has = sym_font.has_char(cp) if sym_font else false
		var def_has = theme.default_font.has_char(cp) if theme.default_font else false
		print("Char '%s' (0x%04X): sym_font=%s, default_font=%s" % [ch, cp, sym_has, def_has])
		
	GameUi.use_game_font(true)
	var gfont = GameUi.game_font()
	print("game_font: ", gfont)
	for ch in chars:
		var cp = ch.unicode_at(0)
		print("Char '%s' in game_font=%s" % [ch, gfont.has_char(cp)])
	quit(0)
