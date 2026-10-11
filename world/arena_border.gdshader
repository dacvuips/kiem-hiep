shader_type canvas_item;
render_mode blend_add;
// Hào quang sáng ở rìa ô vuông màn chơi: viền gắt + quầng sáng mềm hai phía + vệt sáng chạy vòng + nhấp nháy.
// Vẽ lên 1 ColorRect lớn hơn ô vuông 1 khoảng `glow_width` mỗi phía; gốc ô vuông ở giữa ColorRect.

uniform vec2 half_size = vec2(1000.0);      // nửa kích thước ô vuông (px map)
uniform vec2 rect_size = vec2(2300.0);      // kích thước cả ColorRect (px)
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.35, 1.0);
uniform float glow_width = 150.0;
uniform float pulse_speed = 1.6;
uniform float streaks = 6.0;                // số vệt sáng chạy quanh viền
uniform float streak_speed = 0.12;          // vòng/giây

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 q = abs(p) - half_size;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);   // <0 trong ô, >0 ngoài ô
	float ad = abs(d);
	float core = exp(-ad / 5.0);
	float halo = exp(-ad / (glow_width * 0.4)) * (d < 0.0 ? 0.6 : 1.0);
	float ang = atan(p.y, p.x) / TAU + 0.5;
	float streak = pow(max(0.0, sin((ang * streaks - TIME * streak_speed * streaks) * TAU) * 0.5 + 0.5), 5.0);
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	float a = (core * (0.8 + 0.7 * streak) + halo * (0.75 + 0.35 * streak)) * pulse;
	a *= 1.0 - smoothstep(glow_width * 0.55, glow_width, ad);
	vec3 c = mix(glow_color.rgb, vec3(1.0), core * 0.55);
	COLOR = vec4(c * a, a);
}
