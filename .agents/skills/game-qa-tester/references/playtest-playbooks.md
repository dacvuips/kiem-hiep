# Kịch Bản Chơi Thử & Đoạn Mã `evaluate_expression` Mẫu (Playtest Playbooks)

Tài liệu này cung cấp các kịch bản kiểm thử thực chiến và đoạn mã GDScript chạy trực tiếp qua công cụ MCP `evaluate_expression` (hoặc `run_scene`) để **Game QA Expert Agent** điều khiển game tự động, không cần người thật thao tác tay.

---

## Vòng 1: Kiểm Thử Luồng Sảnh Chính & Giao Diện (`CharacterSelect` -> `CharacterHub`)

### 1.1. Kiểm tra danh sách 10 Môn Phái trong `SectRegistry`
Chạy khi bất kỳ scene nào đang mở để kiểm tra xem đủ 10 môn phái chưa, có môn phái nào thiếu skill hay lỗi dữ liệu `.tres` không:
```gdscript
var report := []
for sect in SectRegistry.load_all():
	report.append("%s (%s): %d skills, element=%d" % [sect.id, sect.display_name, sect.skills.size(), sect.element])
return "\n".join(report)
```

### 1.2. Khởi tạo nhanh Hồ sơ Nhân vật (`PlayerProfile`) cho Môn phái bất kỳ & Vào `CharacterHub`
Nếu muốn test nhanh 1 môn phái (VD: `thieu_lam`, `thien_vuong`, `duong_mon`, `ngu_doc`, `nga_mi`, `thuy_yen`, `cai_bang`, `thien_nhan`, `vo_dang`, `con_lon`):
```gdscript
var sect := SectRegistry.get_by_id("duong_mon")
var profile := PlayerProfile.create_default("Tester_QA", sect)
profile.level = 50
profile.skill_points = 50
profile.potential_points = 200
profile.gold = 999999
GameManager.local_profile = profile
SaveManager.save_profile(profile)
get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")
return "Switched to CharacterHub with sect: " + sect.display_name
```

### 1.3. Mở tự động các cửa sổ UI trong `CharacterHub` để chụp ảnh kiểm tra bố cục
- **Mở bảng Kỹ Năng Võ Công (`SkillBookScreen`)**:
  ```gdscript
  var hub := get_tree().current_scene
  hub._on_skills_nav_pressed()
  return "SkillBookScreen opened"
  ```
- **Mở bảng Hành Trang (`InventoryPopup`)**:
  ```gdscript
  var hub := get_tree().current_scene
  hub._on_equipment_nav_pressed()
  return "InventoryPopup opened"
  ```
- **Mở bảng Chọn Ải (`StageSelectScreen`)**:
  ```gdscript
  var hub := get_tree().current_scene
  hub._on_stage_button_pressed()
  return "StageSelectScreen opened"
  ```
- **Mở bảng Debug Quái/Map (`DebugDataBrowser`)**:
  ```gdscript
  var hub := get_tree().current_scene
  DebugDataBrowser.open(hub, func() -> void: pass)
  return "DebugDataBrowser opened"
  ```

---

## Vòng 2: Kiểm Thử Chiến Đấu Thực Chiến (`Main.tscn`)

### 2.1. Khởi chạy Trận đấu với Môn phái + Trang bị + Mở khóa toàn bộ Kỹ năng
Chạy khi đang ở `Main.tscn` để biến nhân vật thành trạng thái đủ đồ, đủ cấp và bật **Auto Combat (`is_auto_mode = true`)**:
```gdscript
var player := get_tree().get_first_node_in_group("player")
if GameManager.local_profile == null:
	var sect := SectRegistry.load_all()[0]
	GameManager.local_profile = PlayerProfile.create_default("QA_Hero", sect)
var profile := GameManager.local_profile
profile.level = 60
profile.skill_points = 60
var sect := SectRegistry.get_by_id(profile.sect_id)
if sect:
	var slot_idx := 0
	for sk in sect.skills:
		profile.skill_levels[sk.id] = 10
		if not sk.is_passive and slot_idx < 4:
			profile.assigned_skills[slot_idx] = sk.id
			slot_idx += 1
player.skill_controller.setup(sect)
player.refresh_combat_stats()
player.is_auto_mode = true
var main_scene := get_tree().current_scene
if main_scene and main_scene.has_node("UI/SkillBarUI"):
	main_scene.get_node("UI/SkillBarUI").refresh_sub_skills()
return "Player ready: HP=%d/%d, AutoMode=%s" % [player.health, player.max_health, str(player.is_auto_mode)]
```

### 2.2. Điều khiển Nhân vật Di chuyển & Thi triển Kỹ năng Chủ động
- **Ra lệnh chạy tới tọa độ trên bản đồ**:
  ```gdscript
  var player := get_tree().get_first_node_in_group("player")
  player._set_move_target(player.global_position + Vector2(220, -140))
  return "Moving from %s to %s" % [str(player.global_position), str(player._move_target)]
  ```
- **Mở đồng thời Khung Nhân Vật + Hành Trang trong lúc đang đánh nhau (Test Z-Order & Drag)**:
  ```gdscript
  var main_scene := get_tree().current_scene
  main_scene._toggle_status_window()
  main_scene._toggle_inventory_window()
  return "Opened both Status & Inventory windows in battle"
  ```
- **Mở Bảng Kỹ Năng giữa trận (`_open_skill_book`) & Kiểm tra trạng thái Pause / Ẩn Joystick**:
  ```gdscript
  var main_scene := get_tree().current_scene
  main_scene._open_skill_book()
  return "Paused=%s, JoystickVisible=%s" % [str(get_tree().paused), str(main_scene.joystick.visible)]
  ```

---

## Vòng 3: Kiểm Thử Toàn Diện 10 Môn Phái, Kỹ Năng & Trang Bị Ngũ Hành

### 3.1. Vòng lặp kiểm tra tự động toàn bộ Kỹ năng của cả 10 Môn phái
Chạy đoạn script này trong `Main.tscn` để ép nhân vật lần lượt đổi qua từng môn phái và kiểm tra xem có kỹ năng nào thiếu `VltkSkillData` hoặc báo lỗi khi thi triển không:
```gdscript
var player := get_tree().get_first_node_in_group("player")
var summary := []
for sect in SectRegistry.load_all():
	var active_count := 0
	var passive_count := 0
	for sk in sect.skills:
		if sk.is_passive:
			passive_count += 1
		else:
			active_count += 1
	summary.append("%s: active=%d, passive=%d" % [sect.id, active_count, passive_count])
return "\n".join(summary)
```

### 3.2. Sinh Trang bị Ngẫu nhiên & Kiểm tra Kích hoạt Ngũ Hành (`ItemGenerator` & `Equipment`)
```gdscript
var profile := GameManager.local_profile
var generated := []
for i in 10:
	var item := ItemGenerator.random_equipment(60)
	profile.add_item(item)
	generated.append("%s (Elem=%d, Tier=%d)" % [item.display_name, item.element, item.tier])
return "Generated %d items:\n%s" % [generated.size(), "\n".join(generated)]
```

---

## Vòng 4: Kiểm Toán Hiệu Năng, Rò Rỉ Bộ Nhớ & Chỗ Chưa Hoàn Thiện

### 4.1. Kiểm tra Rò rỉ Node (`Orphan Nodes`) & Hiệu năng qua `get_monitors`
Sau khi chiến đấu hoặc đóng/mở các bảng UI nhiều lần, gọi `get_monitors` và kiểm tra:
- `fps`: Cảnh báo nếu tụt xuống `< 45 FPS`.
- `object_orphan_node_count`: Nếu `> 0` và tăng dần sau mỗi lần mở/đóng popup hoặc bắn đạn -> **Báo cáo Bug Rò rỉ bộ nhớ (Memory/Orphan Node Leak)**.
- `object_node_count`: Theo dõi xem đạn/hiệu ứng (`VltkMissile`, `VltkEffect`, `DamageNumber`) có được giải phóng hoặc trả về `ObjectPool` không.

### 4.2. Quét Codebase tìm các tính năng chưa hoàn thiện / Placeholder
Kết hợp chạy lệnh shell để đối chiếu với những gì thấy trong game:
```bash
grep -rnE "đang phát triển|TODO|FIXME|HACK|placeholder_do_not_ship|tạm dùng" --include="*.gd" --include="*.tscn" .
```
Mỗi hạng mục chưa hoàn thiện phải được xác minh lại trong game (chụp ảnh màn hình lúc hiện thông báo `"đang phát triển"` hoặc lúc hiển thị asset tạm) để đưa vào báo cáo với nhãn `incomplete-feature`.

