extends Node
## Độ mượt online: tuổi mẫu vị trí trong S_STATE (NetProto v4) + bộ đệm nội suy tự điều chỉnh của NetClient.
## godot --headless --path . res://tests/net_smooth_tests.tscn

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- TEST ĐỘ MƯỢT ONLINE ---")
	check("Server gửi vị trí 18 lần/giây", NetProto.SNAPSHOT_EVERY == 1 and is_equal_approx(NetProto.SNAPSHOT_MS, 1000.0 / 18.0))
	check("Game gửi vị trí >= nhịp server", NetProto.CLIENT_SEND_RATE >= float(NetProto.TICK_RATE) / NetProto.SNAPSHOT_EVERY)

	## Tuổi mẫu: người chơi lấy mẫu lúc 9_940, server gửi lúc 10_000 -> game đặt mẫu ở 9_940.
	var e := ServerEntity.new()
	e.eid = 7
	e.pos = Vector2(1000, 2000)
	e.pos_ms = 9_940
	var t := _decode_time(e, 10_000)
	check("S_STATE mang đúng giờ lấy mẫu (lệch 60ms)", t == 9_940)
	e.pos_ms = 0
	check("Quái / bot (không có giờ mẫu): tuổi 0", _decode_time(e, 10_000) == 10_000)
	e.pos_ms = 8_000
	check("Vị trí server tự đặt (mẫu cũ > 400ms): tuổi 0", _decode_time(e, 10_000) == 10_000)

	## Bộ đệm nội suy: mẫu tới muộn ~30ms -> vẽ trễ ~ 30 + 1 nhịp gửi + đệm; nghẽn 1 lần -> tăng nhanh; rồi hạ chậm.
	NetClient.clock_offset = 1.0
	NetClient._clock_target = 1.0
	NetClient._lateness_peak = [0.0, 0.0]
	NetClient._interp_delay = [NetClient.INTERP_MIN_MS, NetClient.INTERP_MIN_MS]
	for i in 120:
		NetClient.note_sample(NetClient.Interp.PLAYER, NetClient.server_now_ms() - 30.0)
		NetClient._tick_interp(1.0 / 60.0)
	var want := 30.0 + NetProto.SNAPSHOT_MS + NetClient.INTERP_MARGIN_MS
	var d := NetClient.interp_delay_ms(NetClient.Interp.PLAYER)
	check("Độ trễ vẽ theo độ muộn thật (%.0f ~ %.0f ms)" % [d, want], absf(d - want) < 3.0)
	NetClient.note_sample(NetClient.Interp.PLAYER, NetClient.server_now_ms() - 150.0)
	for i in 30:
		NetClient._tick_interp(1.0 / 60.0)
	d = NetClient.interp_delay_ms(NetClient.Interp.PLAYER)
	check("Nghẽn 150ms: trong 0.5 giây đã nâng đệm đủ (%.0f ms)" % d, d >= 150.0 + NetProto.SNAPSHOT_MS - 5.0)
	var before := d
	for i in 60:
		NetClient._tick_interp(1.0 / 60.0)
	d = NetClient.interp_delay_ms(NetClient.Interp.PLAYER)
	check("Hết nghẽn: hạ đệm TỪ TỪ (1 giây giảm %.0f ms)" % (before - d), before - d > 0.0 and before - d <= 25.0)
	check("Quái đo riêng (không bị người chơi kéo theo)",
		NetClient.interp_delay_ms(NetClient.Interp.MONSTER) <= NetProto.SNAPSHOT_MS + NetClient.INTERP_MARGIN_MS + 1.0)

	## Đồng hồ: lệch giờ mới đo không nhảy bậc mà trượt dần.
	NetClient._clock_target = 41.0
	NetClient._tick_interp(0.1)
	check("Lệch giờ trượt dần (không nhảy 40ms một lần)", NetClient.clock_offset > 1.0 and NetClient.clock_offset < 5.0)
	NetClient.clock_offset = 0.0
	NetClient._clock_target = 0.0

	print("RESULT %d/%d" % [_passes, _passes + _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## Ghi 1 mục S_STATE như server rồi đọc giờ mẫu như NetClient.
func _decode_time(e: ServerEntity, now_ms: int) -> int:
	var b := StreamPeerBuffer.new()
	e.write_state(b, now_ms)
	b.seek(0)
	b.get_u32()
	NetProto.get_state_pos(b)
	b.get_u8()
	b.get_u8()
	b.get_u8()
	b.get_u8()
	return now_ms - b.get_u8() * NetProto.STATE_AGE_UNIT_MS

func check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", name)
	else:
		_fails += 1
		print("FAIL ", name)
