shader_type canvas_item;

// Shader mô phỏng chu kỳ Ngày & Đêm tại Sơn Trang Nguyệt Ca Đảo
// Tích hợp quầng sáng quanh nhân vật và các Đống Lửa Sơn Trang (Campfires)

uniform vec2 player_screen_pos = vec2(0.5, 0.5); // Tọa độ UV nhân vật trên màn hình
uniform float player_light_radius : hint_range(0.05, 0.8) = 0.18; // Bán kính vòng sáng quanh nhân vật
uniform float darkness_intensity : hint_range(0.0, 1.0) = 0.86; // Độ tối ban đêm (0.0: Ngày, 0.86: Đêm)
uniform vec4 night_tint : source_color = vec4(0.04, 0.06, 0.18, 1.0); // Tone màu đêm tím biếc
uniform vec2 screen_size = vec2(1280.0, 720.0); // Kích thước màn hình để giữ quầng sáng tròn

// Danh sách các Đống Lửa Sơn Trang (tối đa 8 đống lửa)
const int MAX_CAMPFIRES = 8;
uniform int campfire_count = 4;
uniform vec2 campfire_positions[8];
uniform float campfire_radii[8];
uniform float campfire_intensities[8];
uniform vec4 campfire_colors[8];

void fragment() {
    vec2 uv = SCREEN_UV;
    float aspect = screen_size.x / max(screen_size.y, 1.0);

    // 1. Quầng sáng quanh nhân vật (hình tròn hoàn hảo hiệu chỉnh aspect ratio)
    vec2 p_delta = (uv - player_screen_pos);
    p_delta.x *= aspect;
    float p_dist = length(p_delta);
    float player_light = 1.0 - smoothstep(player_light_radius * 0.35, player_light_radius, p_dist);
    player_light = clamp(player_light, 0.0, 1.0);

    // 2. Vùng sáng xung quanh các Đống Lửa Sơn Trang (1 vòng ngoài duy nhất bao hết 600px)
    float campfire_light_max = 0.0;

    for (int i = 0; i < MAX_CAMPFIRES; i++) {
        if (i >= campfire_count) {
            break;
        }
        if (campfire_intensities[i] > 0.005) {
            vec2 c_delta = (uv - campfire_positions[i]);
            c_delta.x *= aspect;
            float c_dist = length(c_delta);
            float rad = campfire_radii[i];

            // 1 vòng sáng ngoài duy nhất: toàn bộ bên trong sáng rõ ràng, viền ngoài tại 600px chuyển tiếp mượt mà
            float c_light = (1.0 - smoothstep(rad * 0.88, rad, c_dist)) * campfire_intensities[i];
            if (c_light > 0.0) {
                campfire_light_max = max(campfire_light_max, c_light);
            }
        }
    }

    // 3. Tổng hợp ánh sáng từ người chơi và các đống lửa
    float total_light = clamp(player_light * 0.85 + campfire_light_max, 0.0, 1.0);

    // 4. Màn đêm bị đẩy lùi tại các vùng có ánh sáng (trong bán kính 600px sáng trong trẻo, không bị bóng tối phủ)
    float darkness = (1.0 - total_light) * darkness_intensity;

    // 5. Màu sắc đêm tối tự nhiên thuần khiết, không ám lớp màu thừa thãi lên mặt đất
    COLOR = vec4(night_tint.rgb, darkness);
}
