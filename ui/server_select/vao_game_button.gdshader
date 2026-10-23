shader_type canvas_item;

// Kích thước nút và góc vát (chamfer)
uniform vec2 button_size = vec2(270.0, 60.0);
uniform float corner_cut = 8.0;
uniform float border_width = 2.0;

// Màu viền và ánh sáng viền
uniform vec4 border_color : source_color = vec4(1.0, 0.90, 0.45, 1.0);
uniform vec4 border_inner_color : source_color = vec4(0.96, 0.65, 0.12, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.65, 0.08, 0.35);

// Gradient màu nền (Vàng rực rỡ -> Hổ phách -> Nâu đồng)
uniform vec4 col_top : source_color = vec4(1.0, 0.84, 0.28, 1.0);     // #ffd647
uniform vec4 col_mid : source_color = vec4(0.98, 0.63, 0.05, 1.0);     // #faa10d
uniform vec4 col_bot : source_color = vec4(0.55, 0.22, 0.02, 1.0);     // #8c3805

// Hiệu ứng tương tác
uniform float hover_boost : hint_range(0.0, 1.0) = 0.0;
uniform float is_pressed : hint_range(0.0, 1.0) = 0.0;
uniform float is_disabled : hint_range(0.0, 1.0) = 0.0;

// Hàm tính khoảng cách đến hình chữ nhật vát góc (chamfered box SDF)
float sdChamferBox(vec2 p, vec2 b, float r) {
    p = abs(p) - b;
    vec2 q = p + vec2(r);
    float d1 = max(p.x, p.y);
    float d2 = (q.x + q.y) * 0.70710678;
    return max(d1, d2);
}

void fragment() {
    vec2 size = button_size;
    vec2 uv_pixel = (UV - 0.5) * size;
    vec2 half_size = size * 0.5 - vec2(2.0); // Chừa lề cho viền và glow
    
    float d = sdChamferBox(uv_pixel, half_size, corner_cut);
    
    if (d > 0.0) {
        // Hào quang ngoài viền (ambient outer glow)
        float glow = exp(-d * 0.6) * glow_color.a * (1.0 + hover_boost * 0.5);
        COLOR = vec4(glow_color.rgb, glow);
    } else {
        // Gradient nền chính theo chiều dọc (UV.y)
        float y = clamp(UV.y + (is_pressed * 0.05), 0.0, 1.0);
        vec4 bg;
        if (y < 0.45) {
            bg = mix(col_top, col_mid, y / 0.45);
        } else {
            bg = mix(col_mid, col_bot, (y - 0.45) / 0.55);
        }
        
        // Thêm quầng sáng ở giữa theo chiều ngang (radial highlight)
        float center_x = clamp(1.0 - abs(UV.x - 0.5) * 1.8, 0.0, 1.0);
        bg.rgb += vec3(0.12, 0.08, 0.0) * center_x * (1.0 - y * 0.5);
        
        // Viền kim loại vàng
        float edge_dist = -d;
        if (edge_dist <= border_width) {
            float t = edge_dist / border_width;
            vec3 b_col = mix(border_color.rgb, border_inner_color.rgb, t);
            if (UV.y < 0.15) {
                b_col += vec3(0.25, 0.25, 0.2);
            }
            bg.rgb = b_col;
        } else if (edge_dist <= border_width + 1.2) {
            bg.rgb = mix(bg.rgb, vec3(0.3, 0.1, 0.0), 0.5);
        }
        
        // Hiệu ứng hover
        bg.rgb += vec3(0.15, 0.12, 0.05) * hover_boost;
        
        // Hiệu ứng pressed
        if (is_pressed > 0.5) {
            bg.rgb *= 0.88;
        }
        
        // Hiệu ứng disabled
        if (is_disabled > 0.5) {
            float gray = dot(bg.rgb, vec3(0.299, 0.587, 0.114));
            bg.rgb = vec3(gray * 0.7);
            bg.a *= 0.6;
        }
        
        COLOR = bg;
    }
}
