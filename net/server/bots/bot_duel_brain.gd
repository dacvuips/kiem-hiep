class_name BotDuelBrain
extends RefCounted
## Não ĐƠN GIẢN của bước 1 (thử thân bot + chiến đấu server): bám 1 mục tiêu (eid), vào tầm thì ra đòn chính, máu < 50% thì uống thuốc.
## Não "như người" (né, nhảy, bùa, thả diều…) là BotCombatBrain ở bước 2. Trạng thái nằm trên instance (mỗi bot 1 não).

var target_eid := 0

func _init(target := 0) -> void:
	target_eid = target

func think(b: ServerBot, mgr: BotManager, _dt: float) -> void:
	if b.dead:
		return
	var now: float = mgr.gs.now()
	if b.hp_ratio() < 0.5:
		b.drink_potion(now)
	var t: ServerEntity = mgr.gs.entity_of(target_eid) if target_eid != 0 else null
	if t == null or t.room_id != b.room_id or (t.flags & (NetProto.FLAG_DEAD | NetProto.FLAG_HIDE)) != 0:
		b.stop()
		return
	var sk := b.main_skill
	if sk == null:
		return
	var rng := b.skill_range(sk)
	var dist := b.pos.distance_to(t.pos)
	if dist > rng * 0.9:
		b.go_to(t.pos + (b.pos - t.pos).normalized() * rng * 0.6)
		return
	b.stop()
	b.face(t.pos - b.pos)
	mgr.cast(b, sk, t)
