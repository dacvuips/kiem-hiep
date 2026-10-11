package main

import "encoding/json"

// guardClientSave: luật cho dữ liệu nhân vật do GAME gửi thẳng qua HTTP (lúc ở ngoài map — Hub, chọn nhân vật).
// Trong map thì game server lưu (ProfileGuard trong Godot). Ở đây không có công thức game nên dùng BẤT BIẾN:
//   - cấp, kinh nghiệm, tên, môn phái, giới tính, cờ server_seen: giữ bản đã lưu;
//   - tiền (lượng + tiền rương) không tăng; nguyên bảo không tăng;
//   - đồ: chỉ món đã có (theo uid), chỉ số giữ bản đã lưu, chỉ nhận vị trí / khoá / giá; bỏ món lạ / trùng uid;
//   - tổng (4 chỉ số + điểm tiềm năng) không tăng; tổng (cấp các skill + điểm kỹ năng) không tăng.
//
// Nhân vật chưa vào map lần nào (server_seen = 0) thì không chặn: lần vào map đầu game server tự khởi tạo lại phần kinh tế.
var ownerItemFields = []string{"rx", "ry", "rb", "lock", "unlock_at", "price"}

func guardClientSave(oldRaw json.RawMessage, incoming map[string]any) map[string]any {
	var old map[string]any
	if err := json.Unmarshal(oldRaw, &old); err != nil || old == nil {
		return incoming
	}
	if num(old["server_seen"]) == 0 {
		return incoming
	}
	for _, k := range []string{"level", "exp", "name", "sect_id", "sect_name", "gender", "server_seen"} {
		if v, ok := old[k]; ok {
			incoming[k] = v
		}
	}
	// Tiền
	oldTotal := num(old["gold"]) + num(old["storage_gold"])
	if g, b := num(incoming["gold"]), num(incoming["storage_gold"]); g < 0 || b < 0 || g+b > oldTotal {
		incoming["gold"], incoming["storage_gold"] = old["gold"], old["storage_gold"]
	}
	if j := num(incoming["jade"]); j < 0 || j > num(old["jade"]) {
		incoming["jade"] = old["jade"]
	}
	// Điểm
	stats := []string{"strength", "dexterity", "vitality", "energy", "potential_points"}
	if sumOf(incoming, stats) > sumOf(old, stats) || anyNegative(incoming, stats) {
		for _, k := range stats {
			incoming[k] = old[k]
		}
	}
	if skillTotal(incoming) > skillTotal(old) {
		incoming["skill_levels"], incoming["skill_points"] = old["skill_levels"], old["skill_points"]
	}
	// Đồ
	known := map[string]map[string]any{}
	collect := func(it any) {
		if m, ok := it.(map[string]any); ok {
			if uid, _ := m["uid"].(string); uid != "" {
				known[uid] = m
			}
		}
	}
	for _, it := range asList(old["inventory"]) {
		collect(it)
	}
	for _, it := range asList(old["storage"]) {
		collect(it)
	}
	if eq, ok := old["equipment"].(map[string]any); ok {
		for _, it := range eq {
			collect(it)
		}
	}
	seen := map[string]bool{}
	fix := func(it any) map[string]any {
		m, ok := it.(map[string]any)
		if !ok {
			return nil
		}
		uid, _ := m["uid"].(string)
		base, okKnown := known[uid]
		if uid == "" || !okKnown || seen[uid] {
			return nil
		}
		seen[uid] = true
		out := map[string]any{}
		for k, v := range base {
			out[k] = v
		}
		for _, k := range ownerItemFields {
			if v, ok := m[k]; ok {
				out[k] = v
			}
		}
		return out
	}
	for _, key := range []string{"inventory", "storage"} {
		list := []any{}
		for _, it := range asList(incoming[key]) {
			if v := fix(it); v != nil {
				list = append(list, v)
			}
		}
		incoming[key] = list
	}
	newEq := map[string]any{}
	if eq, ok := incoming["equipment"].(map[string]any); ok {
		for k, it := range eq {
			if v := fix(it); v != nil {
				newEq[k] = v
			}
		}
	}
	incoming["equipment"] = newEq
	if num(incoming["storage_extra"]) > max(num(old["storage_extra"]), 5) {
		incoming["storage_extra"] = old["storage_extra"]
	}
	return incoming
}

func num(v any) float64 {
	if f, ok := v.(float64); ok {
		return f
	}
	return 0
}

func sumOf(m map[string]any, keys []string) float64 {
	t := 0.0
	for _, k := range keys {
		t += num(m[k])
	}
	return t
}

func anyNegative(m map[string]any, keys []string) bool {
	for _, k := range keys {
		if num(m[k]) < 0 {
			return true
		}
	}
	return false
}

func skillTotal(m map[string]any) float64 {
	t := num(m["skill_points"])
	if num(m["skill_points"]) < 0 {
		return 1e18
	}
	if sk, ok := m["skill_levels"].(map[string]any); ok {
		for _, v := range sk {
			if num(v) < 0 {
				return 1e18
			}
			t += num(v)
		}
	}
	return t
}

func asList(v any) []any {
	if l, ok := v.([]any); ok {
		return l
	}
	return nil
}
