package main

import (
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config đọc hết từ biến môi trường (xem server/.env.example).
type Config struct {
	HTTPAddr    string
	DatabaseURL string
	JWTIssuer   string
	JWTAudience string
	// Tên miền web được gọi API từ trình duyệt (client web, web Admin), cách nhau dấu phẩy. Rỗng = không cho trình duyệt nào.
	CORSOrigins []string

	AccessTTL  time.Duration
	RefreshTTL time.Duration
	ResetTTL   time.Duration

	SMTPHost string
	SMTPPort int
	SMTPUser string
	SMTPPass string
	MailFrom string

	// Tạo Super Admin đầu tiên khi bảng admins còn trống.
	BootstrapAdminUser string
	BootstrapAdminPass string

	// Đứng sau reverse proxy thì lấy IP thật từ X-Forwarded-For.
	TrustProxy bool

	// Cookie phiên admin chỉ gửi qua HTTPS. Chỉ tắt khi chạy dev bằng http://.
	AdminCookieSecure bool
	// Thư mục web Admin đã build (server phục vụ tại /admin/). Rỗng = không phục vụ.
	AdminWebDir string
}

func loadConfig() Config {
	c := Config{
		HTTPAddr:           env("HTTP_ADDR", ":8080"),
		DatabaseURL:        env("DATABASE_URL", ""),
		JWTIssuer:          env("JWT_ISSUER", "kiemhiep-account"),
		JWTAudience:        env("JWT_AUDIENCE", "kiemhiep-game"),
		CORSOrigins:        splitList(env("CORS_ORIGINS", "")),
		AccessTTL:          envDur("ACCESS_TTL", 15*time.Minute),
		RefreshTTL:         envDur("REFRESH_TTL", 30*24*time.Hour),
		ResetTTL:           envDur("RESET_TTL", 10*time.Minute),
		SMTPHost:           env("SMTP_HOST", "localhost"),
		SMTPPort:           envInt("SMTP_PORT", 1025),
		SMTPUser:           env("SMTP_USER", ""),
		SMTPPass:           env("SMTP_PASS", ""),
		MailFrom:           env("MAIL_FROM", "Kiếm Hiệp <no-reply@kiemhiep.local>"),
		BootstrapAdminUser: env("BOOTSTRAP_ADMIN_USER", ""),
		BootstrapAdminPass: env("BOOTSTRAP_ADMIN_PASS", ""),
		TrustProxy:         env("TRUST_PROXY", "false") == "true",
		AdminCookieSecure:  env("ADMIN_COOKIE_SECURE", "true") != "false",
		AdminWebDir:        env("ADMIN_WEB_DIR", ""),
	}
	if c.DatabaseURL == "" {
		log.Fatal("thiếu DATABASE_URL")
	}
	return c
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func splitList(v string) []string {
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func envInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
		return v
	}
	return def
}

func envDur(k string, def time.Duration) time.Duration {
	if v, err := time.ParseDuration(os.Getenv(k)); err == nil {
		return v
	}
	return def
}
