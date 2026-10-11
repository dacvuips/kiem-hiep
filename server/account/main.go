// Account server: tài khoản người chơi (đăng ký, đăng nhập, quên/đổi mật khẩu), danh sách máy chủ,
// và (sắp tới) API cho web Admin. Không giữ trạng thái trong RAM ngoài rate limit, nên chạy được nhiều bản.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "genkeys" {
		genKeys()
		return
	}
	cfg := loadConfig()
	keys := loadKeyring()
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	if len(os.Args) > 1 && os.Args[1] == "admin" {
		adminCLI(ctx, cfg, keys, os.Args[2:])
		return
	}

	db, err := openDB(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("kết nối database: %v", err)
	}
	defer db.Close()
	if err := migrate(ctx, db); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	if err := bootstrapAdmin(ctx, db, keys, cfg.BootstrapAdminUser, cfg.BootstrapAdminPass); err != nil {
		log.Fatalf("tạo admin đầu tiên: %v", err)
	}

	s := &server{
		cfg:  cfg,
		keys: keys,
		db:   db,
		mail: newMailer(cfg),
		// Theo IP nới rộng vì nhiều người chơi 4G/quán net chung 1 IP; chống dò mật khẩu nằm ở userRL.
		ipRL:   newRateLimiter(120, 60),
		userRL: newRateLimiter(10, 5),
	}
	s.http = &http.Client{Timeout: 10 * time.Second}
	s.googleKeys = &googleKeySet{url: cfg.GoogleJWKSURL, client: s.http}
	go s.cleanupOAuth(ctx)
	if !s.googleEnabled() {
		log.Printf("đăng nhập Google: TẮT (thiếu GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / PUBLIC_BASE_URL)")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("GET /.well-known/jwks.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "public, max-age=300")
		writeJSON(w, http.StatusOK, keys.jwks())
	})
	mux.HandleFunc("POST /v1/auth/register", wrap(s.handleRegister))
	mux.HandleFunc("POST /v1/auth/login", wrap(s.handleLogin))
	mux.HandleFunc("POST /v1/auth/refresh", wrap(s.handleRefresh))
	mux.HandleFunc("POST /v1/auth/logout", wrap(s.handleLogout))
	mux.HandleFunc("POST /v1/auth/forgot", wrap(s.handleForgot))
	mux.HandleFunc("POST /v1/auth/reset", wrap(s.handleReset))
	mux.HandleFunc("POST /v1/account/password", wrap(s.handleChangePassword))
	mux.HandleFunc("GET /v1/account/me", wrap(s.handleMe))
	mux.HandleFunc("POST /v1/auth/google/start", wrap(s.handleGoogleStart))
	mux.HandleFunc("GET /v1/auth/google/callback", s.handleGoogleCallback)
	mux.HandleFunc("POST /v1/auth/google/poll", wrap(s.handleGooglePoll))
	mux.HandleFunc("GET /v1/servers", wrap(s.handleServers))
	mux.HandleFunc("GET /v1/characters", wrap(s.handleListCharacters))
	mux.HandleFunc("POST /v1/characters", wrap(s.handleCreateCharacter))
	mux.HandleFunc("PUT /v1/characters/{id}", wrap(s.handleSaveCharacter))
	mux.HandleFunc("DELETE /v1/characters/{id}", wrap(s.handleDeleteCharacter))

	// Nội bộ: game server
	mux.HandleFunc("POST /internal/game/join", wrap(s.handleInternalJoin))
	mux.HandleFunc("PUT /internal/game/characters/{id}", wrap(s.handleInternalSave))
	mux.HandleFunc("POST /internal/game/status", wrap(s.handleInternalStatus))

	// Web Admin
	mux.HandleFunc("POST /admin/api/login", wrap(s.handleAdminLogin))
	mux.HandleFunc("POST /admin/api/logout", wrap(s.handleAdminLogout))
	mux.HandleFunc("GET /admin/api/me", wrap(s.handleAdminMe))
	mux.HandleFunc("POST /admin/api/me/password", wrap(s.handleAdminChangePassword))
	mux.HandleFunc("POST /admin/api/2fa/setup", wrap(s.handleAdmin2FASetup))
	mux.HandleFunc("POST /admin/api/2fa/enable", wrap(s.handleAdmin2FAEnable))
	mux.HandleFunc("GET /admin/api/stats", wrap(s.handleAdminStats))
	mux.HandleFunc("GET /admin/api/accounts", wrap(s.handleAdminAccounts))
	mux.HandleFunc("GET /admin/api/accounts/{id}", wrap(s.handleAdminAccount))
	mux.HandleFunc("POST /admin/api/accounts/{id}/{action}", wrap(s.handleAdminAccountAction))
	mux.HandleFunc("POST /admin/api/characters/{id}/restore", wrap(s.handleAdminRestoreCharacter))
	mux.HandleFunc("GET /admin/api/servers", wrap(s.handleAdminServers))
	mux.HandleFunc("POST /admin/api/servers", wrap(s.handleAdminSaveServer))
	mux.HandleFunc("PUT /admin/api/servers/{id}", wrap(s.handleAdminSaveServer))
	mux.HandleFunc("GET /admin/api/audit", wrap(s.handleAdminAudit))
	mux.HandleFunc("GET /admin/api/admins", wrap(s.handleAdminAdmins))
	mux.HandleFunc("POST /admin/api/admins", wrap(s.handleAdminCreateAdmin))
	mux.HandleFunc("POST /admin/api/admins/{id}/{action}", wrap(s.handleAdminAdminAction))
	if cfg.AdminWebDir != "" {
		mux.Handle("GET /admin/", adminWeb(cfg.AdminWebDir))
		mux.HandleFunc("GET /admin", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "/admin/", http.StatusFound) })
	}

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           securityHeaders(cors(cfg.CORSOrigins, mux)),
		MaxHeaderBytes:    8 << 10,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		srv.Shutdown(shutdownCtx)
	}()
	log.Printf("account server lắng nghe %s", cfg.HTTPAddr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
