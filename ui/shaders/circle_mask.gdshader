shader_type canvas_item;
// Icon skill VLTK gốc là ảnh vuông có viền khung (sáng trên/trái, tối dưới/phải ~2-3px).
// Mặc định (round_crop = false): KHÔNG cắt tròn — bỏ viền khung của ảnh, rồi thu nội dung còn lại
// thành ô vuông nhỏ hơn canh giữa để nằm gọn trong nút tròn (dùng ở bảng Kỹ Năng).
// round_crop = true (nút skill trên màn chơi): icon phủ KÍN nút, cắt theo hình tròn mép mềm.

// Cạnh ô vuông nội dung / cạnh khung TextureRect (0.70 ≈ vuông nội tiếp hình tròn).
uniform float fit : hint_range(0.3, 1.0) = 0.70;
// Phần viền khung ảnh bị bỏ ở mỗi cạnh (tỉ lệ cạnh ảnh; 3px / 36px ≈ 0.085).
uniform float frame : hint_range(0.0, 0.2) = 0.085;
uniform bool round_crop = false;

void fragment() {
	if (round_crop) {
		vec4 c = texture(TEXTURE, vec2(frame) + UV * (1.0 - 2.0 * frame));
		float d = length(UV - vec2(0.5));
		float aa = fwidth(d) * 1.5;
		c.a *= 1.0 - smoothstep(0.5 - aa, 0.5, d);
		COLOR = c;
	} else {
		float m = (1.0 - fit) * 0.5;
		vec2 t = (UV - vec2(m)) / fit;
		if (t.x < 0.0 || t.y < 0.0 || t.x > 1.0 || t.y > 1.0) {
			COLOR = vec4(0.0);
		} else {
			COLOR = texture(TEXTURE, vec2(frame) + t * (1.0 - 2.0 * frame));
		}
	}
}
