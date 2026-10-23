class_name CharacterAura
extends RefCounted
## Quản lý vòng hào quang dưới chân nhân vật (chuẩn vs35.spr / sprites/player/aura.png - 19 frames).
## Dùng chung cho Player, RemotePlayer và PkBot để đồng bộ hiển thị với mọi người chơi.

const AURA_TEX_PATH := "res://sprites/player/aura.png"
const FRAME_COUNT := 19
const FRAME_SIZE := 400
const AURA_SPEED := 16.0
const AURA_SCALE := Vector2(0.42, 0.42)

static var _cached_frames: SpriteFrames = null

static func get_frames() -> SpriteFrames:
	if _cached_frames != null:
		return _cached_frames
	var frames := SpriteFrames.new()
	var tex := load(AURA_TEX_PATH) as Texture2D
	if tex:
		if not frames.has_animation("default"):
			frames.add_animation("default")
		frames.set_animation_speed("default", AURA_SPEED)
		frames.set_animation_loop("default", true)
		for i in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame("default", atlas)
	_cached_frames = frames
	return _cached_frames

static func create_aura_node() -> AnimatedSprite2D:
	var aura := AnimatedSprite2D.new()
	aura.name = "Aura"
	aura.z_index = -1
	aura.scale = AURA_SCALE
	aura.sprite_frames = get_frames()
	aura.play("default")
	return aura
