shader_type canvas_item;
// Cắt texture thành hình tròn nội tiếp (icon skill vuông trong nút tròn) — viền mờ 1 chút cho mịn.

uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float dist = distance(UV, vec2(0.5));
	color.a *= 1.0 - smoothstep(0.5 - edge_softness, 0.5, dist);
	COLOR = color;
}
