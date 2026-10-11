package main

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

// API nội bộ cho GAME SERVER (không mở cho người chơi): xác thực bằng header X-Service-Key = GAME_SERVICE_KEY.
// Game server không tự kiểm tra JWT (Godot không có Ed25519) mà hỏi ở đây — kèm luôn kiểm tra khóa tài khoản, quyền sở hữu nhân vật.
var errServiceKey = newErr(http.StatusUnauthorized, "service_key", "Sai khóa dịch vụ")

func (s *server) requireService(r *http.Request) error {
	k := r.Header.Get("X-Service-Key")
	if s.cfg.GameServiceKey == "" || subtle.ConstantTimeCompare([]byte(k), []byte(s.cfg.GameServiceKey)) != 1 {
		return errServiceKey
	}
	return nil
}

// POST /internal/game/join {access_token, character_id, server_id}
func (s *server) handleInternalJoin(w http.ResponseWriter, r *http.Request) error {
	if err := s.requireService(r); err != nil {
		return err
	}
	var req struct {
		AccessToken string `json:"access_token"`
		CharacterID int64  `json:"character_id"`
		ServerID    int    `json:"server_id"`
	}
	if err := readJSON(r, &req); err != nil {
		return err
	}
	// Dùng lại đúng đường kiểm tra token của API người chơi (chữ ký, hạn, đổi mật khẩu, khóa tài khoản).
	pr := r.Clone(r.Context())
	pr.Header.Set("Authorization", "Bearer "+req.AccessToken)
	a, err := s.requireAccount(pr)
	if err != nil {
		return err
	}
	var c characterView
	c, err = scanCharacter(s.db.QueryRow(r.Context(), `SELECT `+characterCols+` FROM characters
		WHERE id=$1 AND account_id=$2 AND server_id=$3 AND deleted_at IS NULL`, req.CharacterID, a.ID, req.ServerID))
	if errors.Is(err, pgx.ErrNoRows) {
		return errNoCharacter
	}
	if err != nil {
		return err
	}
	var muted *time.Time
	s.db.QueryRow(r.Context(), `SELECT muted_until FROM accounts WHERE id=$1`, a.ID).Scan(&muted)
	return writeJSON(w, http.StatusOK, map[string]any{
		"account":   map[string]any{"id": a.ID, "username": a.Username, "muted_until": muted},
		"character": c,
	})
}

// PUT /internal/game/characters/{id} {version, data} — game server lưu nhân vật (không cần token người chơi).
func (s *server) handleInternalSave(w http.ResponseWriter, r *http.Request) error {
	if err := s.requireService(r); err != nil {
		return err
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		return errBadRequest
	}
	var req struct {
		Version int             `json:"version"`
		Data    json.RawMessage `json:"data"`
	}
	if err := readLargeJSON(r, &req); err != nil {
		return err
	}
	ctx := r.Context()
	var name string
	if err := s.db.QueryRow(ctx, `SELECT name FROM characters WHERE id=$1 AND deleted_at IS NULL`, id).Scan(&name); errors.Is(err, pgx.ErrNoRows) {
		return errNoCharacter
	} else if err != nil {
		return err
	}
	data, gender, sect, level, err := profileSummary(req.Data, name)
	if err != nil {
		return err
	}
	var version int
	err = s.db.QueryRow(ctx, `UPDATE characters SET data=$2, gender=$3, sect_id=$4, level=$5, version=version+1, updated_at=now()
		WHERE id=$1 AND version=$6 AND deleted_at IS NULL RETURNING version`, id, data, gender, sect, level, req.Version).Scan(&version)
	if errors.Is(err, pgx.ErrNoRows) {
		return errStaleSave
	}
	if err != nil {
		return err
	}
	return writeJSON(w, http.StatusOK, map[string]int{"version": version})
}
