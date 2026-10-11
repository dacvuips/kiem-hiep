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
		cfg:    cfg,
		keys:   keys,
		db:     db,
		mail:   newMailer(cfg),
		// Theo IP nới rộng vì nhiều người chơi 4G/quán net chung 1 IP; chống dò mật khẩu nằm ở userRL.
		ipRL:   newRateLimiter(120, 60),
		userRL: newRateLimiter(10, 5),
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
	mux.HandleFunc("GET /v1/servers", wrap(s.handleServers))

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           securityHeaders(cors(cfg.CORSOrigins, mux)),
		MaxHeaderBytes:    8 << 10,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
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
