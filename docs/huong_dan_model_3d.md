# Model 3D thật cho chế độ 3D (cách 2)

Nhân vật 3D có 2 nguồn hình, cùng một cách gọi (`Character3D.play()` / `face_world()`):

| Nguồn | Mượt | Đổi trang bị | Ở đâu |
|---|---|---|---|
| Hình phẳng VLTK (8 hướng) | xoay nhảy nấc 45° | đủ mọi bộ đồ gốc | `AvatarBaker` nướng từ frame gốc |
| Model 3D thật (.glb / .fbx) | xoay và chuyển động tác liền | chỉ bộ nào có model | `data/avatar3d/models/<tên>/` |

## Thư mục 1 model

```
data/avatar3d/models/<tên>/          (hoặc user://avatar3d/models/<tên>/ — chép vào là dùng, không cần mở editor)
  model.glb | model.gltf | model.fbx   có xương; có thể kèm sẵn động tác
  anim_<gì đó>.fbx / .glb              (tuỳ chọn) mỗi file 1 động tác Mixamo, gộp vào model
  model.json                           (tuỳ chọn)
```

`model.json`:

```json
{
  "height": 0.8,
  "yaw_offset_deg": 0,
  "animations": { "stand": "Idle", "run": "Running", "attack": "Sword Slash",
                  "cast": "Spell Cast", "hurt": "Hit Reaction", "die": "Dying" },
  "speed": { "run": 1.2 }
}
```

- `height`: model tự co cho cao bằng số này (mét). 0.8 = cỡ hình phẳng hiện tại.
- `yaw_offset_deg`: model nhìn lệch hướng thì xoay bù. Mixamo / Tripo quay mặt +Z, để 0.
- `animations`: không ghi thì tự đoán theo tên (idle, run, attack/slash/punch, cast/spell, hit/impact, death...).
  `Character3D.model_animation_for("<động tác>")` cho biết động tác nào đang dùng animation nào.

Mẫu có sẵn: `data/avatar3d/models/nguoi_go/` (người gỗ do `tools/make_test_mannequin.gd` dựng).

## Từ nhân vật VLTK ra model 3D

1. **Xuất ảnh đầu vào**

   ```powershell
   $env:KIEMHIEP_NO_SAVE=1; & "E:\game\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/bake_character_3d.gd -- --helm=3 --armor=5 --weapon=2 --actions=stand --out=user://bake/thu
   ```

   Ra `tripo/front.png, left.png, back.png, right.png` (1024×1024, nền trắng).
   Hình gốc chỉ khoảng 44×78 điểm ảnh và đứng thế võ, nên model dựng thẳng từ đây sẽ thô.

2. **Làm ảnh đẹp hơn (nên làm)**: đưa `front.png` vào công cụ tạo ảnh AI, yêu cầu vẽ lại nhân vật
   **cùng trang phục**, độ phân giải cao, **tư thế chữ A** (tay dang chéo xuống), nhìn thẳng, nền trắng.
   Tư thế chữ A giúp bước gắn xương tự động chính xác.

3. **Tripo** (tripo3d.ai, dịch vụ trả phí): Image to 3D (hoặc Multiview với 4 ảnh) → tải **.glb**.
   Tripo có sẵn bước Rig + Animate; nếu dùng thì tải bản đã có xương và động tác, bỏ qua bước 4.

4. **Mixamo** (miễn phí, cần tài khoản Adobe): tải lên → tự gắn xương → chọn động tác:
   - Bản đầu: **With Skin**, FBX → đổi tên thành `model.fbx`.
   - Các động tác khác: **Without Skin**, FBX → đặt tên `anim_run.fbx`, `anim_attack.fbx`...
   - Nên bật **In Place** cho chạy (nhân vật chạy tại chỗ, game tự dời vị trí).

5. Chép vào `data/avatar3d/models/<tên>/`; nạp bằng `Character3D.load_model(Model3DLoader.model_dir("<tên>"))`.
   Tên động tác đoán sai thì ghi `animations` trong `model.json`.

## Giới hạn hiện tại

- Mỗi bộ đồ cần 1 model riêng. Bộ nào chưa có model thì dùng hình phẳng.
  Hướng lâu dài: 1 thân chung + áo phủ cùng bộ xương + vũ khí gắn vào tay (BoneAttachment3D).
- Map 3D (World3DView) hiện vẽ người là các khối bộ phận (Actor3DRig); chưa nối Character3D / model vào map.
