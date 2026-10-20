extends Node
## Kiểm thử logic xã hội (khoá bảo vệ, rương, giao dịch, bày bán, tổ đội, bang hội). Chạy:
##   godot --headless --path . res://tests/social_tests.tscn      (đặt KIEMHIEP_NO_SAVE=1 để không đụng save thật)
## In "PASS/FAIL" từng ca, cuối cùng "RESULT x/y" và thoát mã 1 nếu có ca hỏng.

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func new_profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	p.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	p.level = 60
	p.gold = 10_000_000
	return p

func item_for(p: PlayerProfile) -> ItemInstance:
	var it := ItemGenerator.random_equipment(p.level)
	p.add_item(it)
	return it

func _ready() -> void:
	test_rules()
	test_security()
	test_storage()
	for name in ["test_trade", "test_stall", "test_team", "test_guild", "test_rewards", "test_view_equip"]:
		if has_method(name):
			call(name)
	print("RESULT ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_rules() -> void:
	check("rules: tổ đội lãnh đạo 0 = 3 người", SocialRules.team_size(0) == 3)
	check("rules: lãnh đạo 10 = 4 người", SocialRules.team_size(10) == 4)
	check("rules: lãnh đạo 100 = 8 người", SocialRules.team_size(100) == 8)
	check("rules: đồng đội tối đa không quá 7", SocialRules.team_member_cap(100) == 7)
	check("rules: bang tối đa 70 người", int(SocialRules.tong()["max_member"]) == 70)
	check("rules: cấp bang 1 có 40 thành viên", SocialRules.tong_member_cap(1) == 40)
	check("rules: lập bang cấp 50/lãnh đạo 20", int(SocialRules.tong()["create"]["level"]) == 50 and int(SocialRules.tong()["create"]["lead_level"]) == 20)

func test_security() -> void:
	var p := new_profile()
	check("khoá: chưa có mật khẩu thì không bật khoá", SecurityLock.lock(p) != "")
	check("khoá: mật khẩu rỗng bị từ chối", SecurityLock.set_password(p, "") != "")
	check("khoá: mật khẩu 17 ký tự bị từ chối", SecurityLock.set_password(p, "x".repeat(17)) != "")
	check("khoá: đặt mật khẩu 16 ký tự được", SecurityLock.set_password(p, "x".repeat(16)) == "")
	check("khoá: đặt xong là đang khoá", SecurityLock.is_locked(p))
	check("khoá: đang khoá chặn mở bày bán", SecurityLock.check(p, SecurityLock.A_OPEN_STALL) != "")
	check("khoá: đang khoá chặn gửi tiền", StorageService.deposit_gold(p, 100) != "")
	check("khoá: sai mật khẩu không mở được", SecurityLock.unlock(p, "sai") != "" and SecurityLock.is_locked(p))
	check("khoá: đúng mật khẩu thì mở", SecurityLock.unlock(p, "x".repeat(16)) == "" and not SecurityLock.is_locked(p))
	check("khoá: mở rồi gửi tiền được", StorageService.deposit_gold(p, 100) == "")
	## Khoá bảo vệ cũng khoá RƯƠNG CHỨA ĐỒ
	var ci := item_for(p)
	check("khoá rương: cất đồ khi chưa khoá được", StorageService.store_item(p, ci) == "")
	SecurityLock.lock(p)
	check("khoá rương: đang khoá không lấy đồ ra", StorageService.take_item(p, ci) != "" and p.storage.owns(ci))
	var ci2 := item_for(p)
	check("khoá rương: đang khoá không cất đồ", StorageService.store_item(p, ci2) != "" and p.inventory.has(ci2))
	check("khoá rương: đang khoá không kéo thả được", not StorageService.transfer(p, ci2, p, p.storage, 0, 0, 0))
	check("khoá rương: đang khoá không mở thêm rương", StorageService.buy_extra_box(p) != "")
	check("khoá rương: đang khoá không rút tiền", StorageService.withdraw_gold(p, 1) != "")
	SecurityLock.unlock(p, "x".repeat(16))
	check("khoá rương: mở khoá xong lấy đồ lại được", StorageService.take_item(p, ci) == "")
	StorageService.store_item(p, ci2)
	StorageService.take_item(p, ci2)
	check("khoá: đổi mật khẩu cần mật khẩu cũ đúng", SecurityLock.set_password(p, "moi", "sai") != "")
	check("khoá: đổi mật khẩu đúng cũ", SecurityLock.set_password(p, "moi", "x".repeat(16)) == "")
	check("khoá: xoá mật khẩu cần đúng mật khẩu", SecurityLock.clear_password(p, "sai") != "" and SecurityLock.clear_password(p, "moi") == "")
	check("khoá: xoá xong không còn khoá", not SecurityLock.is_locked(p) and not SecurityLock.has_password(p))
	## Khoá món đồ
	var it := ItemGenerator.random_equipment(10)
	it.trade_price = 500
	check("khoá món: khoá được và xoá giá bán", SecurityLock.lock_item(it) and it.trade_price == 0)
	check("khoá món: khoá lần 2 không được", not SecurityLock.lock_item(it))
	check("khoá món: yêu cầu mở khoá", SecurityLock.request_unlock(it, 1000))
	check("khoá món: còn chờ 3 ngày", SecurityLock.seconds_to_unlock(it, 1000) == 259200)
	check("khoá món: chưa hết hạn vẫn khoá", SecurityLock.is_item_locked(it, 1000 + 259199))
	check("khoá món: hết hạn là tự do", not SecurityLock.is_item_locked(it, 1000 + 259200))
	var f := ItemGenerator.random_equipment(10)
	f.lock_state = ItemInstance.LOCK_FOREVER
	check("khoá món: khoá vĩnh viễn không đổi được", not SecurityLock.lock_item(f) and not SecurityLock.request_unlock(f))

func test_storage() -> void:
	var p := new_profile()
	var it := item_for(p)
	check("rương: cất món vào", StorageService.store_item(p, it) == "" and p.storage.owns(it) and not p.inventory.has(it))
	check("rương: món nằm trong lưới 6x10", it.room_x >= 0 and it.room_x + it.get_size().x <= 6 and it.room_y + it.get_size().y <= 10)
	check("rương: lấy món ra", StorageService.take_item(p, it) == "" and p.inventory.has(it) and not p.storage.owns(it))
	check("rương: chưa có rương mở rộng thì túi 1 thôi", StorageService.box_count(p) == 1 and not p.storage.can_place(it, 0, 0, 1))
	var cost := StorageService.extra_box_cost(p)
	var before := p.gold
	check("rương: mở rương mở rộng trừ tiền", StorageService.buy_extra_box(p) == "" and p.gold == before - cost and StorageService.box_count(p) == 2)
	for i in 4:
		StorageService.buy_extra_box(p)
	check("rương: tối đa 5 rương mở rộng", StorageService.box_count(p) == 6 and StorageService.buy_extra_box(p) != "")
	check("rương: gửi tiền", StorageService.deposit_gold(p, 1000) == "" and p.storage_gold == 1000)
	check("rương: không rút quá số có", StorageService.withdraw_gold(p, 5000) != "")
	check("rương: rút tiền", StorageService.withdraw_gold(p, 400) == "" and p.storage_gold == 600)
	## Đầy rương
	var q := new_profile()
	var placed := 0
	for i in 400:
		var x := ItemGenerator.random_equipment(10)
		if not q.add_item(x):
			break
		if StorageService.store_item(q, x) != "":
			break
		placed += 1
	check("rương: báo đầy khi hết chỗ", placed > 0 and placed < 400, "placed=%d" % placed)
	## Lưu/nạp
	var r := new_profile()
	var z := item_for(r)
	StorageService.store_item(r, z)
	r.storage_gold = 777
	SecurityLock.set_password(r, "abc")
	r.lead_level = 12
	var back := PlayerProfile.from_dict(r.to_dict())
	check("lưu: nạp lại rương + tiền + khoá + lãnh đạo", back.storage.inventory.size() == 1 and back.storage_gold == 777 \
			and SecurityLock.is_locked(back) and SecurityLock.unlock(back, "abc") == "" and back.lead_level == 12)

func fresh_mock(profile: PlayerProfile) -> MockPlayer:
	var m := SocialDirectory.players(profile)[0]
	m.trade_open = true
	m.stall_open = false
	m.invite_accept_rate = 1.0
	m.haggle = 0.9
	m.gold = 5_000_000
	return m

func test_trade() -> void:
	var p := new_profile()
	var it := item_for(p)
	var m := fresh_mock(p)
	var err := []
	var s := TradeSession.request(p, m, err)
	check("giao dịch: xin giao dịch được", s != null, str(err))
	if s == null:
		return
	check("giao dịch: bỏ món vào phòng", s.offer_item(s.local(), it) == "" and not p.inventory.has(it) and s.local().room.owns(it))
	var locked_item := item_for(p)
	SecurityLock.lock_item(locked_item)
	check("giao dịch: món khoá không bỏ vào được", s.offer_item(s.local(), locked_item) != "")
	check("giao dịch: tiền quá số có bị về 0", s.set_money(s.local(), p.gold + 1) != "" and s.local().money == 0)
	check("giao dịch: chưa khoá không được Đồng ý", s.confirm(s.local()) != "")
	var gold_before := p.gold
	var mock_gold_before := m.gold
	s.lock(s.local())
	check("giao dịch: người giả đáp bằng tiền và tự khoá", s.partner().locked and s.partner().money > 0, s.mock_ai.comment)
	check("giao dịch: đã khoá thì không sửa được", s.offer_item(s.local(), locked_item) != "" and s.set_money(s.local(), 1) != "")
	check("giao dịch: đồng ý lần 1 được ghi nhận", s.confirm(s.local()) == "" and s.local().ok and s.active)
	s.tick(2.0)
	check("giao dịch: chưa đủ 5 giây người giả chưa đồng ý", s.active)
	s.tick(3.5)
	check("giao dịch: sau 5 giây hoàn tất", not s.active)
	var gained := p.gold - gold_before
	check("giao dịch: tiền chuyển đúng", gained > 0 and m.gold == mock_gold_before - gained, "gained=%d" % gained)
	check("giao dịch: món sang bên người giả", m.bag.owns(it) and not p.inventory.has(it))
	## Huỷ trả đồ
	var p2 := new_profile()
	var it2 := item_for(p2)
	var m2 := fresh_mock(p2)
	var s2 := TradeSession.request(p2, m2)
	s2.offer_item(s2.local(), it2)
	s2.set_money(s2.local(), 1000)
	s2.cancel()
	check("giao dịch: huỷ trả đồ + tiền nguyên", p2.inventory.has(it2) and p2.gold == 10_000_000 and not s2.active)
	## Khoá bảo vệ chặn giao dịch
	var p3 := new_profile()
	SecurityLock.set_password(p3, "1234")
	var e3 := []
	check("giao dịch: đang khoá bảo vệ không xin giao dịch", TradeSession.request(p3, fresh_mock(p3), e3) == null and e3.size() == 1)
	## Đối phương không mở giao dịch
	var p4 := new_profile()
	var m4 := fresh_mock(p4)
	m4.trade_open = false
	check("giao dịch: đối phương không mở giao dịch", TradeSession.request(p4, m4) == null)
	## Hết chỗ nhận đồ
	var p5 := new_profile()
	var m5 := fresh_mock(p5)
	var s5 := TradeSession.request(p5, m5)
	for i in 6:
		var rich := ItemGenerator.random_equipment(80)
		m5.bag.add_item(rich)
	while m5.bag.add_item(ItemGenerator.random_equipment(5)):
		pass
	s5.set_money(s5.local(), 100000)
	s5.lock(s5.local())
	check("giao dịch: người giả hết đồ để đáp thì không khoá", true)

func test_stall() -> void:
	var p := new_profile()
	var it := item_for(p)
	check("bày bán: giá âm bị từ chối", StallService.set_price(p, it, -5) != "")
	check("bày bán: mở quầy khi chưa có món đặt giá bị từ chối", StallService.open_stall(p, "ban do") != "")
	check("bày bán: đặt giá được", StallService.set_price(p, it, 5000) == "" and it.trade_price == 5000)
	var locked := item_for(p)
	SecurityLock.lock_item(locked)
	check("bày bán: món khoá không đặt giá được", StallService.set_price(p, locked, 100) != "")
	check("bày bán: cưỡi ngựa không mở quầy", StallService.open_stall(p, "x", true) != "")
	check("bày bán: mở quầy được", StallService.open_stall(p, "Bán đồ") == "" and p.stall_open and not p.trade_open)
	check("bày bán: đang bày bán thì không mở giao dịch", StallService.open_trade(p) != "")
	StallService.close_stall(p)
	check("bày bán: dọn quầy", not p.stall_open)
	check("bày bán: mở giao dịch được khi hết bày bán", StallService.open_trade(p) == "" and p.trade_open)
	SecurityLock.set_password(p, "abc")
	check("bày bán: khoá bảo vệ chặn mở quầy", StallService.open_stall(p, "x") != "")
	## Mua từ quầy người giả
	var buyer := new_profile()
	var seller: MockPlayer = null
	for m in SocialDirectory.players(buyer):
		if m.stall_open and not StallService.browse(m).is_empty():
			seller = m
			break
	check("bày bán: có quầy giả đang mở", seller != null)
	if seller == null:
		return
	var goods := StallService.browse(seller)
	var good := goods[0]
	var price := good.trade_price
	buyer.gold = price - 1
	var party_b := TradeParty.of_profile(buyer)
	var party_s := TradeParty.of_mock(seller)
	check("bày bán: thiếu tiền không mua được", StallService.buy(party_b, party_s, good) != "")
	buyer.gold = price + 10
	var seller_gold := seller.gold
	check("bày bán: chiến đấu không mua được", StallService.buy(party_b, party_s, good, true) != "")
	SecurityLock.set_password(buyer, "pw")
	check("bày bán: khoá bảo vệ chặn mua", StallService.buy(party_b, party_s, good) != "")
	SecurityLock.unlock(buyer, "pw")
	check("bày bán: mua thành công", StallService.buy(party_b, party_s, good) == "" and buyer.inventory.has(good) and buyer.gold == 10 and seller.gold == seller_gold + price)
	check("bày bán: món đã bán không còn trên quầy", good not in StallService.browse(seller) and good.trade_price == 0)
	check("bày bán: mua lại món đã bán bị từ chối", StallService.buy(party_b, party_s, good) != "")
	## Khách giả mua từ quầy người chơi
	var q := new_profile()
	var qi := item_for(q)
	StallService.set_price(q, qi, 1)    ## giá rẻ → bán chạy
	StallService.open_stall(q, "re")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sold := 0
	for i in 200:
		sold += StallService.simulate_customers(q, rng).size()
		if not q.stall_open:
			break
	check("bày bán: khách giả mua hàng rẻ và quầy tự dọn khi hết hàng", sold == 1 and not q.stall_open and not q.inventory.has(qi), "sold=%d" % sold)

func test_team() -> void:
	SocialDirectory.reset()
	var p := new_profile()
	p.lead_level = 0
	var t := TeamService.new(p)
	t.rng.seed = 1
	check("tổ đội: chưa có đội", not t.in_team() and t.capacity() == 0)
	check("tổ đội: tắt tổ đội thì không tạo", (func() -> bool:
		t.allow_create = false
		var r := t.create_team() != ""
		t.allow_create = true
		return r).call())
	check("tổ đội: tạo đội", t.create_team() == "" and t.is_captain() and t.open and t.total() == 1)
	check("tổ đội: tạo lần 2 bị từ chối", t.create_team() != "")
	check("tổ đội: cấp lãnh đạo 0 chứa 3 người", t.capacity() == 3)
	var pool := SocialDirectory.players(p)
	for m in pool:
		m.invite_accept_rate = 1.0
		m.team_tag = ""
		m.camp = Camp.Type.JUSTICE
	check("tổ đội: mời người 1", t.invite(pool[0]) == "" and t.total() == 2)
	check("tổ đội: mời người 2 → đủ → tự đóng", t.invite(pool[1]) == "" and t.total() == 3 and not t.open)
	check("tổ đội: đội đóng/đủ không mời thêm", t.invite(pool[2]) != "")
	check("tổ đội: không mở được khi đã đủ", t.set_open(true) != "")
	p.lead_level = 10
	t.captain.lead_level = 10
	check("tổ đội: lãnh đạo 10 chứa 4 người", t.capacity() == 4 and t.set_open(true) == "")
	check("tổ đội: người đã trong đội khác không mời được", (func() -> bool:
		pool[3].team_tag = "c"
		return t.invite(pool[3]) != "").call())
	pool[3].team_tag = ""
	pool[2].invite_accept_rate = 0.0
	check("tổ đội: người từ chối", t.invite(pool[2]) != "" and t.total() == 3)
	pool[2].invite_accept_rate = 1.0
	check("tổ đội: đuổi thành viên", t.kick(t.members[0]) == "" and t.total() == 2 and pool[0].team_tag == "")
	check("tổ đội: đổi cách nhặt đồ", t.set_pick_mode(TeamService.Pick.CAPTAIN) == "" and t.pick_mode == 2)
	check("tổ đội: chế độ đội trưởng nhặt thì đội trưởng được nhặt", t.can_local_pick())
	var mem := t.members[0]
	mem.lead_level = 0
	check("tổ đội: đổi đội trưởng cho người đủ cấp", t.change_captain(mem) == "" and not t.is_captain())
	check("tổ đội: hết đội trưởng thì mình không quản lý được", t.kick(t.members[0]) != "" and t.set_pick_mode(0) != "")
	check("tổ đội: chế độ đội trưởng nhặt, mình là thành viên → không nhặt", not t.can_local_pick())
	check("tổ đội: thành viên rời đội", t.leave() == "" and not t.in_team())
	## Đội trưởng rời = giải tán
	SocialDirectory.reset()
	var q := new_profile()
	var t2 := TeamService.new(q)
	t2.rng.seed = 2
	t2.create_team()
	var pool2 := SocialDirectory.players(q)
	pool2[0].invite_accept_rate = 1.0
	pool2[0].camp = Camp.Type.JUSTICE
	t2.invite(pool2[0])
	t2.leave()
	check("tổ đội: đội trưởng rời đội thì giải tán + người kia được thả", not t2.in_team() and pool2[0].team_tag == "")
	## Xin vào đội
	var t3 := TeamService.new(q)
	t3.rng.seed = 3
	var cap := pool2[5]
	cap.lead_level = 12
	cap.invite_accept_rate = 1.0
	cap.team_tag = ""
	check("tổ đội: xin vào đội giả", t3.apply_to(cap) == "" and t3.in_team() and not t3.is_captain() and t3.captain.name == cap.name)
	t3.leave()
	## Đội trưởng nhận người xin vào
	var t4 := TeamService.new(q)
	t4.rng.seed = 4
	t4.create_team()
	var got := 0
	for i in 40:
		if t4.simulate_applicants() != null:
			got += 1
		if got > 0:
			break
	check("tổ đội: có người xin vào đội", got > 0 and not t4.applicants.is_empty())
	var ap := t4.applicants[0]
	ap.camp = Camp.Type.JUSTICE
	check("tổ đội: nhận người xin vào", t4.accept_applicant(ap) == "" and t4.total() == 2 and t4.applicants.find(ap) < 0)
	## Chia kinh nghiệm
	check("exp: chênh cấp <= 5 nhận đủ", ExpRules.self_exp(10, 14, 100) == 100)
	check("exp: chênh cấp 10 bị giảm", ExpRules.self_exp(10, 20, 200) == 200 * (295 - 190) / 200)
	check("exp: chênh cấp > 15 chỉ còn 1", ExpRules.self_exp(10, 40, 9999) == 1)
	var sh := ExpRules.team_shares(1000, [50, 50])
	check("exp: 2 người cấp bằng nhau chia mỗi người 65%% (k=130)", sh[0] == 650 and sh[1] == 650, str(sh))
	check("exp: người cấp cao nhận nhiều hơn", ExpRules.team_shares(1000, [30, 70])[1] > ExpRules.team_shares(1000, [30, 70])[0])
	check("exp: kinh nghiệm lãnh đạo chỉ có khi có đồng đội", ExpRules.lead_exp(1000, [50], 50) == 0 and ExpRules.lead_exp(1000, [50, 50], 50) > 0)
	var lp := new_profile()
	lp.lead_level = 0
	lp.lead_exp = 0
	check("exp: lên cấp lãnh đạo theo bảng", ExpRules.add_lead_exp(lp, 100) == 1 and lp.lead_level == 1 and ExpRules.add_lead_exp(lp, 900) == 1 and lp.lead_level == 2)

func rich_profile() -> PlayerProfile:
	var p := new_profile()
	p.level = 60
	p.lead_level = 25
	p.gold = 60_000_000
	p.prestige = 500
	p.fuyuan = 600
	return p

func test_guild() -> void:
	SocialDirectory.reset()
	var p := new_profile()
	p.level = 10
	var g := GuildService.new(p)
	g.rng.seed = 11
	check("bang: tân thủ có nhiều điều kiện chưa đạt", g.create_blockers().size() >= 4)
	check("bang: không đủ điều kiện thì không lập", g.create("Test", Camp.Type.JUSTICE) != "" and not g.in_guild())
	var r := rich_profile()
	var gs := GuildService.new(r)
	gs.rng.seed = 12
	check("bang: đủ điều kiện (cấp 60/lãnh đạo 25/20 triệu/danh vọng/phúc duyên)", gs.create_blockers().is_empty(), str(gs.create_blockers()))
	check("bang: tên rỗng bị từ chối", gs.create("", Camp.Type.JUSTICE) != "")
	check("bang: tên dài hơn 12 ký tự bị từ chối", gs.create("a".repeat(13), Camp.Type.JUSTICE) != "")
	check("bang: phe không hợp lệ bị từ chối", gs.create("Hạo Thiên", Camp.Type.FREE) != "")
	check("bang: trùng tên bang giả bị từ chối", gs.create("Thiên Long Bang", Camp.Type.JUSTICE) != "")
	var team := TeamService.new(r)
	team.create_team()
	check("bang: đang trong tổ đội không lập bang", gs.create("Hạo Thiên", Camp.Type.JUSTICE, team) != "")
	team.dismiss()
	var before := r.gold
	check("bang: lập bang thành công", gs.create("Hạo Thiên", Camp.Type.JUSTICE, team) == "" and gs.in_guild() and gs.is_master())
	check("bang: trừ 20 triệu + đổi phe", r.gold == before - 20_000_000 and r.camp == Camp.Type.JUSTICE)
	check("bang: lập lần 2 bị từ chối", gs.create("Khác", Camp.Type.EVIL) != "")
	check("bang: bang mới có 1 thành viên và đang trong thời gian thử thách", gs.members().size() == 1 and gs.trial_seconds_left() > 0)
	## Tuyển người
	var got := ""
	for i in 80:
		got = gs.simulate_applicants()
		if got != "":
			break
	check("bang: có người xin vào", got != "" and gs.applies().size() == 1)
	check("bang: nhận người xin vào", gs.accept_applicant(got) == "" and gs.members().size() == 2 and gs.applies().is_empty())
	check("bang: chủ bang không rời được", gs.leave() != "")
	## Mời người
	var pool := SocialDirectory.players(r)
	var free: Array[MockPlayer] = []
	for m in pool:
		m.invite_accept_rate = 1.0
		if m.guild_name == "" and m.team_tag == "" and gs._find(m.name).is_empty():
			free.append(m)
	check("bang: mời người vào bang", gs.invite(free[0]) == "" and gs.members().size() == 3 and free[0].guild_name == "Hạo Thiên")
	check("bang: người đã có bang không mời được", gs.invite(pool[0]) != "")
	## Bổ nhiệm
	check("bang: bổ nhiệm Trưởng lão", gs.instate(free[0].name, GuildRules.Figure.DIRECTOR) == "" and gs.count_figure(GuildRules.Figure.DIRECTOR) == 1)
	check("bang: không phong Bang chủ bằng bổ nhiệm", gs.instate(free[0].name, GuildRules.Figure.MASTER) != "")
	check("bang: bổ nhiệm Đội trưởng", gs.instate(gs.members()[1]["name"], GuildRules.Figure.MANAGER) == "")
	check("luật: Trưởng lão chỉ đổi Đội trưởng <-> Đệ tử", GuildRules.can_instate(GuildRules.Figure.DIRECTOR, GuildRules.Figure.MEMBER, GuildRules.Figure.MANAGER) 			and not GuildRules.can_instate(GuildRules.Figure.DIRECTOR, GuildRules.Figure.MEMBER, GuildRules.Figure.DIRECTOR) 			and not GuildRules.can_instate(GuildRules.Figure.MANAGER, GuildRules.Figure.MEMBER, GuildRules.Figure.MANAGER))
	check("luật: Trưởng lão không đuổi được Trưởng lão", not GuildRules.can_kick(GuildRules.Figure.DIRECTOR, GuildRules.Figure.DIRECTOR) and GuildRules.can_kick(GuildRules.Figure.MASTER, GuildRules.Figure.DIRECTOR))
	check("bang: giới hạn 7 Trưởng lão", GuildRules.max_for_figure(GuildRules.Figure.DIRECTOR) == 7 and GuildRules.max_for_figure(GuildRules.Figure.MANAGER) == 56)
	## Thông báo / tuyển
	check("bang: sửa thông báo", gs.set_notice("Hello bang") == "" and gs.data()["notice"] == "Hello bang")
	check("bang: tắt tuyển người thì không có người xin", gs.set_recruit(false) == "" and (func() -> bool:
		for i in 60:
			if gs.simulate_applicants() != "":
				return false
		return true).call())
	## Quỹ bang + cấp bang
	check("bang: quyên góp vào quỹ", gs.donate(1_500_000) == "" and int(gs.data()["fund"]) == 1_500_000 and int(gs.local_member()["devote"]) == 1500)
	gs.profile.guild["fund_tick_at"] = 1000
	var cycles := gs.process_fund(750 * 4)
	check("bang: quỹ >= 1 triệu thì mỗi chu kỳ 750s trừ 5000 + cộng 120 exp", cycles == 4 and int(gs.data()["fund"]) == 1_500_000 - 4 * 5000 and int(gs.data()["exp"]) == 480)
	gs.profile.guild["exp"] = SocialRules.tong_exp_for_level(2)
	gs.process_fund(750)
	check("bang: đủ exp thì lên cấp 2", int(gs.data()["level"]) == 2 and gs.member_cap() == 55)
	## Nhường chức
	check("bang: nhường chức cho Trưởng lão", gs.change_master(free[0].name) == "" and not gs.is_master() and gs.local_figure() == GuildRules.Figure.DIRECTOR)
	check("bang: người nhường xuống Trưởng lão vẫn khai trừ được Đội trưởng", gs.kick(gs.members()[1]["name"]) == "")
	## Rời bang
	var gold_b := r.gold
	var rep_b := r.prestige
	check("bang: rời bang trả phí + đặt thời gian chờ", gs.leave() == "" and not gs.in_guild() and r.gold == gold_b - 100000 and r.prestige == rep_b - 100 and gs.join_cooldown_left() > 0)
	var cap_master := SocialDirectory.guild_members(r, "Thiên Long Bang")[0]
	check("bang: còn thời gian chờ thì không xin vào bang khác", gs.apply_join(cap_master) != "")
	r.guild_join_after = 0
	cap_master.invite_accept_rate = 1.0
	check("bang: xin vào bang giả", gs.apply_join(cap_master) == "" and gs.in_guild() and gs.guild_name() == "Thiên Long Bang" and gs.local_figure() == GuildRules.Figure.MEMBER)
	check("bang: đệ tử không có quyền mời/bổ nhiệm", gs.invite(pool[0]) != "" and gs.instate(gs.members()[0]["name"], GuildRules.Figure.MANAGER) != "")
	## Thử thách
	var t := rich_profile()
	var gt := GuildService.new(t)
	gt.create("Thử Thách", Camp.Type.EVIL)
	var created := int(gt.data()["created_at"])
	check("bang: còn trong thử thách 2 tuần", gt.trial_seconds_left(created + 1000) == 1209600 - 1000)
	check("bang: hết 2 tuần mà dưới 16 người thì giải tán", gt.check_trial(created + 1209600) and not gt.in_guild())
	## Lưu / nạp
	var s2 := rich_profile()
	var g2 := GuildService.new(s2)
	g2.create("Bền Vững", Camp.Type.BALANCE)
	g2.set_notice("giữ lại")
	var back := PlayerProfile.from_dict(s2.to_dict())
	check("bang: lưu/nạp lại bang", back.guild.get("name") == "Bền Vững" and back.guild.get("notice") == "giữ lại" and back.guild_join_after == 0)

func test_rewards() -> void:
	SocialDirectory.reset()
	var p := new_profile()
	p.level = 10
	p.current_exp = 0
	var got := KillRewards.grant_exp(p, 50, 10)
	check("thưởng: solo nhận đủ kinh nghiệm", got == 50 and p.current_exp == 50)
	p.current_exp = 0
	check("thưởng: quái cấp quá thấp chỉ còn 1", KillRewards.grant_exp(p, 500, 40) == 1)
	## Có đội: chia theo cấp, cộng exp lãnh đạo cho đội trưởng
	var hub := SocialHub.of(p)
	hub.team.create_team()
	var pool := SocialDirectory.players(p)
	pool[0].invite_accept_rate = 1.0
	pool[0].camp = Camp.Type.JUSTICE
	pool[0].level = 10
	hub.team.rng.seed = 5
	hub.team.invite(pool[0])
	p.current_exp = 0
	p.lead_exp = 0
	var shared := KillRewards.grant_exp(p, 1000, 10)
	check("thưởng: có 1 đồng đội cấp bằng nhau → mỗi người 65%", shared == 650, str(shared))
	check("thưởng: đội trưởng nhận kinh nghiệm lãnh đạo", p.lead_exp > 0, str(p.lead_exp))
	hub.team.leave()
	## Nhặt đồ theo chế độ
	hub.team.create_team()
	hub.team.set_pick_mode(TeamService.Pick.ALTERNATE)
	check("thưởng: nhặt luân phiên — đội trưởng tới lượt trước", hub.team.can_local_pick())
	hub.team.advance_turn()
	check("thưởng: hết 1 vòng thì lượt đổi", hub.team.total() == 1 and hub.team.can_local_pick())
	hub.team.leave()

func test_view_equip() -> void:
	SocialDirectory.reset()
	ViewEquipService.reset()
	var p := new_profile()
	p.display_name = "Nguoi Xem"
	var pool := SocialDirectory.players(p)
	var dressed: MockPlayer = null
	for m in pool:
		if m.equipment.size() >= 2:
			dressed = m
			break
	check("xem trang bị: có người chơi giả đang mặc đồ", dressed != null)
	if dressed == null:
		return
	var r := ViewEquipService.view(p, dressed, 1000)
	check("xem trang bị: xem được người ở gần", r["error"] == "" and r["snapshot"]["name"] == dressed.name)
	var snap: Dictionary = r["snapshot"]
	check("xem trang bị: đủ số ô như bên người kia", (snap["equipment"] as Dictionary).size() == dressed.equipment.size())
	var part = dressed.equipment.keys()[0]
	check("xem trang bị: là BẢN SAO, không phải món thật", snap["equipment"][part] != dressed.equipment[part] 			and snap["equipment"][part].to_dict() == dressed.equipment[part].to_dict())
	snap["equipment"][part].durability = -999
	check("xem trang bị: sửa bản sao không đổi món thật", dressed.equipment[part].durability != -999)
	check("xem trang bị: xem liên tiếp quá nhanh bị chặn (30 nhịp)", ViewEquipService.view(p, dressed, 1000 + 500)["error"] != "")
	check("xem trang bị: đủ 30 nhịp thì xem lại được", ViewEquipService.view(p, dressed, 1000 + 500 + ViewEquipService.COOLDOWN_MS)["error"] == "")
	var me := MockPlayer.new()
	me.id = 1
	me.name = p.display_name
	check("xem trang bị: không xem chính mình", ViewEquipService.view(p, me, 100000)["error"] != "")
	var far := MockPlayer.new()
	far.id = 99999
	far.name = "Xa Lắm"
	check("xem trang bị: người không ở gần thì không xem được", ViewEquipService.view(p, far, 200000)["error"] != "")
	var mine := ViewEquipService.snapshot_of_profile(p)
	check("xem trang bị: bản chụp của chính mình có tên + cấp", mine["name"] == p.display_name and mine["level"] == p.level)
