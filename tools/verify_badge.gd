extends SceneTree

func _init() -> void:
	print("--- TEST AGE RATING BADGE ---")
	var badge := AgeRatingBadge.new()
	assert(badge != null, "Badge instance must not be null")
	
	# Add to a test root control
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(1280, 720)
	root_control.size = Vector2(1280, 720)
	root.add_child(root_control)
	root_control.add_child(badge)
	
	print("Badge created. Name: ", badge.name)
	print("Badge position: ", badge.position)
	print("Badge size: ", badge.size)
	assert(badge.position == Vector2(18.0, 10.0), "Badge position must be (18, 10)")
	assert(badge.size == Vector2(44.0, 44.0), "Badge size must be (44, 44)")

	var tex_rect: TextureRect = badge.get_node_or_null("BadgeTexture") as TextureRect
	assert(tex_rect != null, "BadgeTexture child must exist")
	print("TextureRect found: ", tex_rect)
	print("Texture loaded: ", tex_rect.texture)
	assert(tex_rect.texture != null, "Texture must be loaded")
	print("Texture dimensions: ", tex_rect.texture.get_size())
	assert(tex_rect.texture.get_size() == Vector2(300, 300), "Texture size should be 300x300")
	print("Tooltip: ", tex_rect.tooltip_text)
	assert("18+" in tex_rect.tooltip_text, "Tooltip must mention 18+")

	# Test info popup on click
	badge._show_info_popup()
	var notice := badge.get_node_or_null("NoticeLabel") as Label
	assert(notice != null, "NoticeLabel should be spawned on info trigger")
	print("NoticeLabel text: ", notice.text)
	assert("18+" in notice.text, "Notice must mention 18+")

	print("ALL AGE RATING BADGE TESTS PASSED SUCCESSFULLY!")
	quit(0)
