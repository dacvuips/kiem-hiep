package main

import "net/http"

type gameServerView struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	Region     string `json:"region"`
	Status     string `json:"status"`
	IsNew      bool   `json:"is_new"`
	Host       string `json:"host"`
	Port       int    `json:"port"`
	WSURL      string `json:"ws_url"`
	Characters int    `json:"characters"` // số nhân vật của tài khoản trên máy chủ này (có ở bước lưu nhân vật)
}

// handleServers trả danh sách máy chủ đúng định dạng màn Chọn máy chủ đang đọc ({"servers": [...]}).
func (s *server) handleServers(w http.ResponseWriter, r *http.Request) error {
	if _, err := s.requireAccount(r); err != nil {
		return err
	}
	rows, err := s.db.Query(r.Context(),
		`SELECT id, name, region, status, is_new, host, port, ws_url FROM game_servers ORDER BY sort_order, id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	list := []gameServerView{}
	for rows.Next() {
		var g gameServerView
		if err := rows.Scan(&g.ID, &g.Name, &g.Region, &g.Status, &g.IsNew, &g.Host, &g.Port, &g.WSURL); err != nil {
			return err
		}
		list = append(list, g)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	return writeJSON(w, http.StatusOK, map[string]any{"servers": list})
}
