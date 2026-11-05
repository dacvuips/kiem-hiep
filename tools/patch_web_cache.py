import os
import sys

tools_dir = os.path.dirname(os.path.abspath(__file__))
project_dir = os.path.abspath(os.path.join(tools_dir, ".."))
web_dir = os.path.join(project_dir, "build", "web")
index_path = os.path.join(web_dir, "index.html")

if not os.path.exists(index_path):
    print(f"[!] Khong tim thay {index_path}")
    sys.exit(0)

pck_path = os.path.join(web_dir, "index.pck")
wasm_path = os.path.join(web_dir, "index.wasm")

pck_size = os.path.getsize(pck_path) if os.path.exists(pck_path) else 1174742592
wasm_size = os.path.getsize(wasm_path) if os.path.exists(wasm_path) else 38820072
pck_mtime = int(os.path.getmtime(pck_path)) if os.path.exists(pck_path) else 1
wasm_mtime = int(os.path.getmtime(wasm_path)) if os.path.exists(wasm_path) else 1
build_version = f"{pck_size}_{pck_mtime}"
content_path = os.path.join(web_dir, "content.pck")
content_size = os.path.getsize(content_path) if os.path.exists(content_path) else 1200000000
content_mtime = int(os.path.getmtime(content_path)) if os.path.exists(content_path) else 1
build_version = f"{pck_size}_{pck_mtime}"
wasm_version = f"{wasm_size}_{wasm_mtime}"
content_version = f"{content_size}_{content_mtime}"

TEMPLATE = """<!DOCTYPE html>
<html lang="vi">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0">
		<title>JX1 Idle Origin - Võ Lâm Truyền Kỳ</title>
		
		<!-- Xóa và chặn toàn bộ console logs trên Web Console -->
		<script>
		(function () {
			try {
				const noop = function () {};
				['log', 'info', 'warn', 'debug', 'error', 'table', 'trace', 'dir', 'dirxml', 'group', 'groupCollapsed', 'groupEnd', 'time', 'timeEnd', 'timeLog', 'assert'].forEach(function (m) {
					window.console[m] = noop;
				});
				window.console.clear();
			} catch (e) {}

			// Phát hiện sớm điện thoại / máy tính bảng (Mobile / Tablet) để chặn tức thì không tải tài nguyên nặng
			try {
				var ua = (navigator.userAgent || navigator.vendor || window.opera || '').toLowerCase();
				var hasTouch = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0) || (navigator.msMaxTouchPoints > 0);
				var isCoarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
				var isCompact = (window.innerWidth <= 1024 && window.innerHeight <= 1366) || (window.screen && Math.min(window.screen.width, window.screen.height) <= 850);
				var isMob = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini|mobile|tablet|silk|kindle|playbook|bb10/i.test(ua)
					|| (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
					|| (/macintosh/i.test(ua) && navigator.maxTouchPoints > 1)
					|| ((hasTouch || isCoarse) && isCompact);

				if (isMob) {
					document.documentElement.className += ' mobile-blocked';
					window.__IS_MOBILE_DEVICE = true;
				} else {
					window.__IS_MOBILE_DEVICE = false;
				}
			} catch (e) {
				window.__IS_MOBILE_DEVICE = false;
			}
		})();
		</script>

		<link rel="preconnect" href="https://fonts.googleapis.com">
		<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
		<link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;900&family=Be+Vietnam+Pro:wght@400;500;600;700&display=swap" rel="stylesheet">
		<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />
		<link rel="apple-touch-icon" href="index.apple-touch-icon.png"/>

		<style>
* {
	box-sizing: border-box;
}

html, body, #canvas {
	margin: 0;
	padding: 0;
	border: 0;
	width: 100%;
	height: 100%;
}

body {
	color: #e6dfd5;
	background-color: #050403;
	overflow: hidden;
	touch-action: none;
	font-family: 'Be Vietnam Pro', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	user-select: none;
	-webkit-user-select: none;
}

#canvas {
	display: block;
	width: 100%;
	height: 100%;
}

#canvas:focus {
	outline: none;
}

/* ========================================================
   LOADING SCREEN OVERLAY (WUXIA / VO LAM THEME)
   ======================================================== */
#status {
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	background: radial-gradient(circle at 50% 36%, #1c140d 0%, #0d0a08 55%, #050403 100%);
	display: flex;
	flex-direction: column;
	justify-content: center;
	align-items: center;
	z-index: 9999;
	overflow: hidden;
	transition: opacity 0.6s ease-out;
}

/* Hào quang huyền ảo sau Logo */
.ambient-glow {
	position: absolute;
	width: 520px;
	height: 520px;
	border-radius: 50%;
	background: radial-gradient(circle, rgba(245, 158, 11, 0.16) 0%, rgba(2, 132, 199, 0.09) 45%, transparent 70%);
	filter: blur(50px);
	pointer-events: none;
	animation: pulseGlow 5.5s ease-in-out infinite alternate;
}

@keyframes pulseGlow {
	0% { transform: scale(0.92); opacity: 0.6; }
	100% { transform: scale(1.18); opacity: 0.95; }
}

/* Khung nội dung chính */
.loader-card {
	position: relative;
	width: 90%;
	max-width: 490px;
	display: flex;
	flex-direction: column;
	align-items: center;
	z-index: 2;
}

/* Logo Game */
.logo-wrapper {
	position: relative;
	margin-bottom: 22px;
	display: flex;
	justify-content: center;
	align-items: center;
}

.splash-logo {
	max-width: 330px;
	width: 82vw;
	height: auto;
	object-fit: contain;
	filter: drop-shadow(0 0 22px rgba(245, 158, 11, 0.45)) drop-shadow(0 0 42px rgba(0, 180, 216, 0.25));
	animation: logoBreathing 3.8s ease-in-out infinite;
}

@keyframes logoBreathing {
	0%, 100% { transform: translateY(0) scale(1); }
	50% { transform: translateY(-5px) scale(1.02); }
}

/* Khung tiến trình nạp */
.progress-box {
	width: 100%;
	margin-bottom: 14px;
}

.progress-header {
	display: flex;
	justify-content: space-between;
	align-items: baseline;
	margin-bottom: 8px;
	padding: 0 4px;
}

.progress-state {
	font-size: 13px;
	color: #e5d5b8;
	font-weight: 500;
	letter-spacing: 0.3px;
	text-shadow: 0 1px 3px rgba(0,0,0,0.8);
}

.progress-percent {
	font-family: 'Cinzel', 'Be Vietnam Pro', serif;
	font-size: 21px;
	font-weight: 700;
	color: #fbbf24;
	text-shadow: 0 0 12px rgba(251, 191, 36, 0.65);
}

.progress-track {
	position: relative;
	width: 100%;
	height: 15px;
	background: rgba(18, 12, 9, 0.92);
	border: 1.5px solid rgba(217, 178, 100, 0.55);
	border-radius: 20px;
	overflow: hidden;
	box-shadow: inset 0 2px 5px rgba(0,0,0,0.85), 0 0 14px rgba(217, 178, 100, 0.2);
}

.progress-fill {
	height: 100%;
	width: 0%;
	background: linear-gradient(90deg, #d97706 0%, #f59e0b 35%, #fbbf24 60%, #38bdf8 85%, #00e5ff 100%);
	border-radius: 20px;
	position: relative;
	transition: width 0.25s ease-out;
	box-shadow: 0 0 14px rgba(245, 158, 11, 0.75);
}

.progress-shimmer {
	position: absolute;
	top: 0; left: 0; bottom: 0; right: 0;
	background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.45) 50%, transparent 100%);
	animation: shimmerMove 2.2s infinite;
}

@keyframes shimmerMove {
	0% { transform: translateX(-100%); }
	100% { transform: translateX(200%); }
}

.progress-footer {
	display: flex;
	justify-content: space-between;
	margin-top: 6px;
	padding: 0 4px;
	font-size: 11.5px;
	color: #9c8a77;
}

.progress-speed {
	color: #38bdf8;
	font-weight: 600;
}

/* Thẻ thông báo tải 1 lần duy nhất (SSD Cache) */
.cache-notice {
	width: 100%;
	display: flex;
	align-items: center;
	gap: 12px;
	background: linear-gradient(135deg, rgba(28, 19, 13, 0.88) 0%, rgba(16, 11, 7, 0.95) 100%);
	border: 1px solid rgba(217, 178, 100, 0.4);
	border-radius: 10px;
	padding: 10px 14px;
	margin-bottom: 12px;
	box-shadow: 0 4px 16px rgba(0,0,0,0.5), inset 0 0 12px rgba(217, 178, 100, 0.06);
	backdrop-filter: blur(8px);
}

.cache-notice-icon {
	font-size: 22px;
	flex-shrink: 0;
	filter: drop-shadow(0 0 8px rgba(245, 158, 11, 0.6));
}

.cache-notice-body {
	flex: 1;
}

.cache-notice-title {
	font-size: 11px;
	font-weight: 700;
	color: #fbbf24;
	letter-spacing: 0.6px;
	text-transform: uppercase;
	margin-bottom: 2px;
}

.cache-notice-desc {
	font-size: 11.5px;
	line-height: 1.45;
	color: #d1c2ab;
}

.cache-notice-desc strong {
	color: #fff;
	text-decoration: underline;
	text-decoration-color: rgba(251, 191, 36, 0.5);
}

/* Thẻ Mẹo chơi ngẫu nhiên (Bí Kíp Bôn Tẩu) */
.tips-box {
	width: 100%;
	background: rgba(14, 10, 7, 0.82);
	border: 1px dashed rgba(217, 178, 100, 0.35);
	border-radius: 8px;
	padding: 10px 14px;
	min-height: 52px;
	display: flex;
	flex-direction: column;
	justify-content: center;
}

.tips-header {
	display: flex;
	align-items: center;
	gap: 6px;
	margin-bottom: 4px;
}

.tips-icon {
	font-size: 13px;
}

.tips-title {
	font-size: 10.5px;
	font-weight: 700;
	letter-spacing: 0.8px;
	color: #f59e0b;
	text-transform: uppercase;
}

.tip-text {
	font-size: 11.8px;
	line-height: 1.45;
	color: #c9b89d;
	font-style: italic;
	transition: opacity 0.35s ease-in-out, transform 0.35s ease-in-out;
}

.tip-text.fade-out {
	opacity: 0;
	transform: translateY(-4px);
}

.tip-text.fade-in {
	opacity: 1;
	transform: translateY(0);
}

/* Thông báo lỗi nếu có */
#status-notice {
	display: none;
	width: 100%;
	background-color: #5b2128;
	border-radius: 0.5rem;
	border: 1px solid #9b3943;
	color: #fecdd3;
	font-size: 12.5px;
	line-height: 1.4;
	margin-top: 12px;
	padding: 0.75rem;
	text-align: center;
	z-index: 10;
}

@media (max-width: 480px) {
	.splash-logo {
		max-width: 275px;
	}
	.progress-percent {
		font-size: 19px;
	}
	.cache-notice {
		padding: 8px 11px;
		gap: 9px;
	}
	.cache-notice-icon {
		font-size: 19px;
	}
	.cache-notice-title {
		font-size: 10.5px;
	}
	.cache-notice-desc {
		font-size: 10.8px;
	}
	.tip-text {
		font-size: 11.2px;
	}
}

/* ========================================================
   MOBILE & TABLET BLOCK OVERLAY (CHẶN ĐIỆN THOẠI & TABLET)
   ======================================================== */
#mobile-block-overlay {
	display: none;
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	width: 100%;
	height: 100%;
	background: radial-gradient(circle at 50% 25%, #241912 0%, #0d0a08 65%, #050403 100%);
	z-index: 100000;
	flex-direction: column;
	justify-content: flex-start;
	align-items: center;
	padding: 24px 16px;
	box-sizing: border-box;
	overflow-y: auto;
	-webkit-overflow-scrolling: touch;
}

html.mobile-blocked #mobile-block-overlay {
	display: flex !important;
}

html.mobile-blocked #status,
html.mobile-blocked #canvas {
	display: none !important;
}

.mb-backdrop-glow {
	position: absolute;
	width: 480px;
	height: 480px;
	border-radius: 50%;
	background: radial-gradient(circle, rgba(245, 158, 11, 0.15) 0%, rgba(184, 50, 38, 0.08) 50%, transparent 70%);
	filter: blur(50px);
	pointer-events: none;
	top: 5%;
	left: 50%;
	transform: translateX(-50%);
}

.mb-card {
	position: relative;
	max-width: 460px;
	width: 100%;
	background: rgba(18, 13, 10, 0.94);
	border: 1px solid rgba(217, 178, 100, 0.45);
	border-radius: 16px;
	padding: 26px 20px;
	box-shadow: 0 15px 40px rgba(0, 0, 0, 0.9), 0 0 25px rgba(217, 178, 100, 0.18);
	text-align: center;
	margin: auto 0;
}

.mb-logo-wrapper {
	margin-bottom: 12px;
}

.mb-logo {
	max-width: 210px;
	height: auto;
	filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.8));
}

.mb-badge {
	display: inline-block;
	background: rgba(220, 38, 38, 0.15);
	border: 1px solid rgba(239, 68, 68, 0.4);
	color: #fca5a5;
	font-size: 11px;
	font-weight: 700;
	letter-spacing: 1.2px;
	padding: 4px 14px;
	border-radius: 20px;
	margin-bottom: 12px;
	text-transform: uppercase;
}

.mb-title {
	font-family: 'Cinzel', 'Be Vietnam Pro', serif;
	font-size: 18px;
	font-weight: 700;
	color: #ffd700;
	letter-spacing: 0.5px;
	margin: 0 0 12px 0;
	line-height: 1.4;
	text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8);
}

.mb-alert-text {
	font-size: 13px;
	line-height: 1.6;
	color: #d1c2ab;
	margin-bottom: 18px;
}

.mb-alert-text strong {
	color: #fef08a;
}

.mb-pc-box {
	background: rgba(255, 255, 255, 0.04);
	border: 1px dashed rgba(217, 178, 100, 0.4);
	border-radius: 10px;
	padding: 14px 16px;
	margin-bottom: 18px;
	text-align: left;
}

.mb-pc-header {
	display: flex;
	align-items: center;
	gap: 8px;
	margin-bottom: 6px;
}

.mb-pc-icon {
	font-size: 20px;
}

.mb-pc-title {
	font-size: 12px;
	font-weight: 700;
	color: #60a5fa;
	letter-spacing: 0.5px;
}

.mb-pc-desc {
	font-size: 12px;
	line-height: 1.5;
	color: #cbd5e1;
	margin-bottom: 12px;
}

.mb-pc-desc em {
	color: #93c5fd;
	font-style: normal;
}

.btn-copy-link {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 8px;
	width: 100%;
	background: rgba(30, 41, 59, 0.7);
	border: 1px solid rgba(148, 163, 184, 0.3);
	color: #f1f5f9;
	font-size: 12.5px;
	font-weight: 600;
	padding: 9px 14px;
	border-radius: 8px;
	cursor: pointer;
	transition: all 0.2s ease;
}

.btn-copy-link:hover, .btn-copy-link:active {
	background: rgba(51, 65, 85, 0.9);
	border-color: #ffd700;
	color: #ffd700;
}

.mb-apk-box {
	background: linear-gradient(180deg, rgba(30, 20, 14, 0.7) 0%, rgba(20, 14, 10, 0.9) 100%);
	border: 1px solid rgba(245, 158, 11, 0.45);
	border-radius: 12px;
	padding: 16px;
	box-shadow: 0 4px 15px rgba(0, 0, 0, 0.5);
}

.mb-apk-header {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 6px;
	margin-bottom: 6px;
}

.mb-apk-icon {
	font-size: 20px;
}

.mb-apk-title {
	font-size: 12px;
	font-weight: 700;
	color: #f59e0b;
	letter-spacing: 0.6px;
	text-transform: uppercase;
}

.mb-apk-desc {
	font-size: 12px;
	line-height: 1.5;
	color: #e2e8f0;
	margin-bottom: 14px;
}

.mb-apk-desc strong {
	color: #fbbf24;
}

.btn-download-apk {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 12px;
	background: linear-gradient(135deg, #f59e0b 0%, #d97706 50%, #b45309 100%);
	border: 1px solid #fbbf24;
	color: #120902;
	text-decoration: none;
	padding: 13px 18px;
	border-radius: 10px;
	box-shadow: 0 4px 18px rgba(245, 158, 11, 0.45);
	transition: all 0.25s ease;
}

.btn-download-apk:active, .btn-download-apk:hover {
	transform: translateY(-2px);
	box-shadow: 0 6px 24px rgba(245, 158, 11, 0.7);
	background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 50%, #d97706 100%);
}

.btn-apk-icon {
	font-size: 26px;
	flex-shrink: 0;
}

.btn-apk-content {
	display: flex;
	flex-direction: column;
	text-align: left;
}

.btn-apk-main {
	font-size: 14.5px;
	font-weight: 800;
	letter-spacing: 0.5px;
	color: #120902;
	line-height: 1.25;
}

.btn-apk-sub {
	font-size: 11px;
	font-weight: 600;
	color: #3b1e06;
	line-height: 1.3;
	margin-top: 2px;
}

.mb-guide-link {
	display: inline-block;
	color: #f4d38c;
	font-size: 12px;
	text-decoration: underline;
	transition: color 0.2s;
}

.mb-guide-link:hover {
	color: #ffffff;
}

.mb-ios-tip {
	font-size: 11px;
	line-height: 1.45;
	color: #94a3b8;
	margin-top: 12px;
	border-top: 1px dashed rgba(255, 255, 255, 0.1);
	padding-top: 10px;
}


/* ========================================================
   MOBILE INPUT MODAL (DOM NATIVE INPUT CHO DIEN THOAI)
   ======================================================== */
#mobile-input-modal {
	position: fixed;
	top: 0; left: 0; right: 0; bottom: 0;
	z-index: 1000000;
	display: none;
	justify-content: center;
	align-items: flex-start;
	padding-top: 15px;
	box-sizing: border-box;
}

.mobile-input-backdrop {
	position: absolute;
	top: 0; left: 0; right: 0; bottom: 0;
	background: rgba(0, 0, 0, 0.75);
	backdrop-filter: blur(4px);
}

.mobile-input-box {
	position: relative;
	width: 92%;
	max-width: 440px;
	background: linear-gradient(135deg, #1f1610 0%, #120c09 100%);
	border: 1.5px solid rgba(217, 178, 100, 0.65);
	border-radius: 14px;
	box-shadow: 0 10px 30px rgba(0, 0, 0, 0.9), 0 0 20px rgba(217, 178, 100, 0.2);
	padding: 16px 18px;
	box-sizing: border-box;
	z-index: 2;
}

.mobile-input-header {
	display: flex;
	align-items: center;
	justify-content: space-between;
	margin-bottom: 12px;
}

.mobile-input-title {
	font-family: 'Cinzel', 'Be Vietnam Pro', serif;
	font-size: 15px;
	font-weight: 700;
	color: #fbbf24;
	letter-spacing: 0.5px;
	flex: 1;
	margin-left: 8px;
}

.mobile-input-close {
	background: none;
	border: none;
	color: #9c8a77;
	font-size: 20px;
	cursor: pointer;
	padding: 2px 8px;
	line-height: 1;
}

.mobile-input-body {
	margin-bottom: 14px;
}

#mobile-input-field {
	width: 100%;
	height: 44px;
	background: rgba(10, 7, 5, 0.9);
	border: 1.5px solid rgba(217, 178, 100, 0.5);
	border-radius: 8px;
	color: #ffffff;
	font-size: 16px;
	padding: 0 12px;
	outline: none;
	box-sizing: border-box;
	font-family: 'Be Vietnam Pro', sans-serif;
}

#mobile-input-field:focus {
	border-color: #fbbf24;
	box-shadow: 0 0 10px rgba(251, 191, 36, 0.4);
}

.mobile-input-footer {
	display: flex;
	gap: 10px;
	justify-content: flex-end;
}

.mobile-input-btn {
	padding: 9px 18px;
	border-radius: 8px;
	font-size: 13.5px;
	font-weight: 600;
	cursor: pointer;
	border: none;
}

.btn-cancel {
	background: rgba(255, 255, 255, 0.12);
	color: #d1c2ab;
}

.btn-confirm {
	background: linear-gradient(135deg, #d97706 0%, #f59e0b 50%, #fbbf24 100%);
	color: #120b05;
	font-weight: 700;
}

		</style>
	</head>
	<body>
		<canvas id="canvas">
			Trình duyệt của bạn không hỗ trợ thẻ canvas HTML5.
		</canvas>

		<noscript>
			Trình duyệt của bạn đang tắt JavaScript. Vui lòng bật lại để chơi game.
		</noscript>

		<!-- MÀN HÌNH CHẶN TRUY CẬP TRÊN THIẾT BỊ DI ĐỘNG & MÁY TÍNH BẢNG (MOBILE / TABLET) -->
		<div id="mobile-block-overlay">
			<div class="mb-backdrop-glow"></div>
			<div class="mb-card">
				<!-- Logo Game -->
				<div class="mb-logo-wrapper">
					<img src="index.png" alt="JX1 Idle Origin" class="mb-logo">
				</div>

				<div class="mb-badge">
					<span>⚔️ THÔNG BÁO BẢN WEB ⚔️</span>
				</div>

				<h2 class="mb-title">VUI LÒNG MỞ TRÌNH DUYỆT TRÊN MÁY TÍNH</h2>

				<div class="mb-alert-text">
					Phiên bản Web của <strong>JX1 Idle Origin</strong> yêu cầu màn hình rộng và bàn phím máy tính để tối ưu trải nghiệm. Game <strong>không hỗ trợ chơi trực tiếp qua trình duyệt trên Điện thoại &amp; Máy tính bảng (Tablet)</strong>.
				</div>

				<!-- Hướng dẫn dành cho Máy tính PC/Laptop -->
				<div class="mb-pc-box">
					<div class="mb-pc-header">
						<span class="mb-pc-icon">💻</span>
						<span class="mb-pc-title">TRẢI NGHIỆM BẢN WEB TRÊN PC / LAPTOP</span>
					</div>
					<div class="mb-pc-desc">
						Quý huynh đệ hãy mở trình duyệt <em>(Chrome, Cốc Cốc, Edge...)</em> trên máy tính để vào game trực tiếp mà không cần cài đặt.
					</div>
					<button id="btn-copy-link" class="btn-copy-link" onclick="window.copyGameWebLink()">
						<span>📋</span> Sao Chép Liên Kết Web
					</button>
				</div>

				<!-- Tải App Android (APK) dành cho Điện thoại & Tablet -->
				<div class="mb-apk-box">
					<div class="mb-apk-header">
						<span class="mb-apk-icon">📱</span>
						<span class="mb-apk-title">CHƠI TRÊN ĐIỆN THOẠI &amp; MÁY TÍNH BẢNG</span>
					</div>
					<div class="mb-apk-desc">
						Bổn môn đã phát hành bản cài đặt <strong>Android (APK)</strong> chính thức, mượt mà và tối ưu thao tác cảm ứng:
					</div>
					
					<a href="https://kiem-hiep-api.viettheo.site/download/kiem-hiep-launcher.apk" class="btn-download-apk" download="kiem-hiep-launcher.apk">
						<span class="btn-apk-icon">📥</span>
						<span class="btn-apk-content">
							<span class="btn-apk-main">TẢI BẢN CÀI ĐẶT ANDROID (APK)</span>
							<span class="btn-apk-sub">Bản chính thức • ~113 MB • Cài đặt nhanh</span>
						</span>
					</a>

					<div style="margin-top: 10px;">
						<a href="https://kiem-hiep-api.viettheo.site/download/" target="_blank" class="mb-guide-link">
							📖 Xem trang hướng dẫn tải &amp; cài đặt chi tiết
						</a>
					</div>

					<div class="mb-ios-tip">
						🍎 <em>Lưu ý với iPhone / iPad: Vui lòng mở trình duyệt trên máy tính PC / Laptop để chơi bản Web.</em>
					</div>
				</div>
			</div>
		</div>

		<!-- Modal Nhập Liệu Chuẩn Native Cho Điện Thoại -->
		<div id="mobile-input-modal">
			<div class="mobile-input-backdrop" onclick="window.cancelMobileInput()"></div>
			<div class="mobile-input-box">
				<div class="mobile-input-header">
					<span style="font-size: 18px;">⚔️</span>
					<span id="mobile-input-title" class="mobile-input-title">Nhập Thông Tin</span>
					<button class="mobile-input-close" onclick="window.cancelMobileInput()">✕</button>
				</div>
				<div class="mobile-input-body">
					<input id="mobile-input-field" type="text" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" placeholder="Nhập tại đây...">
				</div>
				<div class="mobile-input-footer">
					<button class="mobile-input-btn btn-cancel" onclick="window.cancelMobileInput()">Hủy</button>
					<button class="mobile-input-btn btn-confirm" onclick="window.confirmMobileInput()">Xác Nhận</button>
				</div>
			</div>
		</div>

		<!-- Giao diện Loading Võ Lâm Tu Chân -->
		<div id="status">
			<div class="ambient-glow"></div>
			
			<div class="loader-card">
				<!-- Logo Game -->
				<div class="logo-wrapper">
					<img id="status-splash" class="splash-logo" src="index.png" alt="JX1 Idle Origin">
				</div>

				<!-- Thanh tiến trình % -->
				<div class="progress-box">
					<div class="progress-header">
						<span id="progress-state" class="progress-state">Đang nạp tài nguyên võ lâm...</span>
						<span id="progress-percent" class="progress-percent">0%</span>
					</div>
					
					<div class="progress-track">
						<div id="progress-bar-fill" class="progress-fill">
							<div class="progress-shimmer"></div>
						</div>
					</div>

					<div class="progress-footer">
						<span id="progress-bytes" class="progress-bytes">Đang chuẩn bị...</span>
						<span id="progress-speed" class="progress-speed">⚡ Tốc độ cao</span>
					</div>
				</div>

				<!-- Thông điệp tải 1 lần duy nhất vào bộ nhớ máy -->
				<div class="cache-notice">
					<div class="cache-notice-icon" id="cache-icon">💾</div>
					<div class="cache-notice-body">
						<div class="cache-notice-title" id="cache-title">⚡ KHỞI ĐỘNG CỰC NHANH - TẢI NGẦM NỀN</div>
						<div class="cache-notice-desc" id="cache-desc">
							Mở game vào Đăng Nhập / Tạo Nhân Vật tức thì! Toàn bộ bản đồ thế giới (~1.2 GB) được tải ngầm dưới nền và lưu vĩnh viễn trên SSD máy.
						</div>
					</div>
				</div>

				<!-- Mẹo chơi ngẫu nhiên -->
				<div class="tips-box">
					<div class="tips-header">
						<span class="tips-icon">💡</span>
						<span class="tips-title">MẸO BÔN TẨU GIANG HỒ</span>
					</div>
					<div id="tip-text" class="tip-text">Ngũ Hành Tương Khắc: Kim &gt; Mộc &gt; Thổ &gt; Thủy &gt; Hỏa &gt; Kim. Tấn công hệ bị khắc nhận thêm 30% sát thương!</div>
				</div>

				<div style="margin-top: 14px; text-align: center;">
					<button onclick="window.forceClearCacheAndReload()" style="background: rgba(0,0,0,0.5); border: 1px solid rgba(255,215,0,0.35); color: #ffd700; font-size: 11.5px; padding: 5px 12px; border-radius: 6px; cursor: pointer; transition: all 0.2s;">
						🔄 Tải lại bản mới nhất (Xóa Cache)
					</button>
				</div>

				<div id="status-notice"></div>
			</div>
		</div>

		<script>
window.__IS_FROM_SSD = false;

window.copyGameWebLink = function () {
	var url = window.location.href;
	var btn = document.getElementById('btn-copy-link');
	function showSuccess() {
		if (!btn) return;
		var original = btn.innerHTML;
		btn.innerHTML = '<span>✅</span> Đã Sao Chép Liên Kết!';
		btn.style.borderColor = '#10b981';
		btn.style.color = '#34d399';
		setTimeout(function () {
			btn.innerHTML = original;
			btn.style.borderColor = '';
			btn.style.color = '';
		}, 2500);
	}
	if (navigator.clipboard && navigator.clipboard.writeText) {
		navigator.clipboard.writeText(url).then(showSuccess).catch(function () {
			fallbackCopy(url);
		});
	} else {
		fallbackCopy(url);
	}
	function fallbackCopy(text) {
		var ta = document.createElement('textarea');
		ta.value = text;
		ta.style.position = 'fixed';
		ta.style.opacity = '0';
		document.body.appendChild(ta);
		ta.select();
		try {
			document.execCommand('copy');
			showSuccess();
		} catch (e) {
			alert('Hãy sao chép liên kết này: ' + text);
		}
		document.body.removeChild(ta);
	}
};

// Tự động dọn dẹp các cache bị hỏng/dở dang từ các phiên bản cũ
(async function cleanupStaleCaches() {
	try {
		if ('serviceWorker' in navigator) {
			const regs = await navigator.serviceWorker.getRegistrations();
			for (const r of regs) {
				r.unregister().catch(() => {});
			}
		}
		if (navigator.storage && navigator.storage.getDirectory) {
			const root = await navigator.storage.getDirectory();
			for await (const name of root.keys()) {
				if (name.startsWith('index_') || name.endsWith('.pck') || name.endsWith('.wasm')) {
					root.removeEntry(name, { recursive: true }).catch(() => {});
				}
			}
		}
	} catch (e) {}
})();

// Nút xóa sạch toàn bộ cache và tải lại game từ đầu
window.forceClearCacheAndReload = async function () {
	if (confirm('Xóa toàn bộ bộ nhớ đệm và tải lại game từ đầu?')) {
		try {
			if ('serviceWorker' in navigator) {
				const regs = await navigator.serviceWorker.getRegistrations();
				for (const r of regs) await r.unregister();
			}
			if (navigator.storage && navigator.storage.getDirectory) {
				const root = await navigator.storage.getDirectory();
				for await (const name of root.keys()) {
					await root.removeEntry(name, { recursive: true }).catch(() => {});
				}
			}
			if ('caches' in window) {
				const keys = await caches.keys();
				for (const k of keys) await caches.delete(k);
			}
			try {
				localStorage.clear();
				sessionStorage.clear();
			} catch (e) {}
		} catch (e) {}
		window.location.href = window.location.pathname + '?nocache=' + Date.now();
	}
};

// Hộp thoại nhập liệu Native cho Mobile Web (bàn phím ảo điện thoại gõ tiếng Việt mượt mà)
window.openMobileInput = function (title, currentVal, isSecret) {
	const modal = document.getElementById('mobile-input-modal');
	const titleEl = document.getElementById('mobile-input-title');
	const inputEl = document.getElementById('mobile-input-field');
	if (!modal || !inputEl) return;
	if (titleEl && title) titleEl.textContent = title;
	inputEl.type = isSecret ? 'password' : 'text';
	inputEl.value = currentVal || '';
	modal.style.display = 'flex';
	setTimeout(function () {
		inputEl.focus();
		if (inputEl.setSelectionRange) {
			const len = inputEl.value.length;
			inputEl.setSelectionRange(len, len);
		}
	}, 120);
};

window.confirmMobileInput = function () {
	const modal = document.getElementById('mobile-input-modal');
	const inputEl = document.getElementById('mobile-input-field');
	if (!modal || !inputEl) return;
	const val = inputEl.value;
	modal.style.display = 'none';
	if (window.__mobileInputCallback && typeof window.__mobileInputCallback === 'function') {
		window.__mobileInputCallback(val);
	}
};

window.cancelMobileInput = function () {
	const modal = document.getElementById('mobile-input-modal');
	if (modal) modal.style.display = 'none';
};

document.addEventListener('DOMContentLoaded', function () {
	const inputEl = document.getElementById('mobile-input-field');
	if (inputEl) {
		inputEl.addEventListener('keydown', function (e) {
			if (e.key === 'Enter') {
				e.preventDefault();
				window.confirmMobileInput();
			}
		});
	}
});
		</script>
		<script src="index.js?v=__BUILD_VERSION__"></script>
		<script>
const GODOT_CONFIG = {
	"args": [],
	"canvasResizePolicy": 2,
	"emscriptenPoolSize": 8,
	"ensureCrossOriginIsolationHeaders": true,
	"executable": "index",
	"experimentalVK": true,
	"fileSizes": {
		"index.pck": __PCK_SIZE__,
		"index.pck?v=__BUILD_VERSION__": __PCK_SIZE__,
		"index.wasm": __WASM_SIZE__,
		"index.wasm?v=__WASM_VERSION__": __WASM_SIZE__
	},
	"focusCanvas": true,
	"gdextensionLibs": [],
	"godotPoolSize": 4,
	"mainPack": "index.pck",
	"onPrint": function () {},
	"onPrintError": function () {}
};
const GODOT_THREADS_ENABLED = true;
const engine = new Engine(GODOT_CONFIG);

// Wrapper preloadFile de nap file chinh xac phien ban bo qua cache hong
const origPreloadFile = engine.preloadFile.bind(engine);
engine.preloadFile = function (file, path) {
	const versionedFile = file.includes('?') ? file : (file + '?v=__BUILD_VERSION__');
	return origPreloadFile(versionedFile, path);
};

(function () {
	// Danh sach meo choi ngau nhien
	const TIPS = [
		"Ngũ Hành Tương Khắc: Kim > Mộc > Thổ > Thủy > Hỏa > Kim. Tấn công hệ bị khắc nhận thêm 30% sát thương!",
		"Đặc tính Ngũ Hành: Kim gây Thọ Thương, Mộc gây Trúng Độc, Thủy gây Làm Chậm, Hỏa gây Bỏng Cháy, Thổ gây Choáng.",
		"Treo Máy Bế Quan: Dù bạn thoát game, nhân vật vẫn miệt mài tu luyện, tích lũy Bạc, Exp và nhặt trang bị quý.",
		"Cường Hóa Huyền Tinh: Đạt mốc cường hóa +4, +8, +12, +16 sẽ kích hoạt các dòng thuộc tính ẩn cực mạnh.",
		"Cộng Điểm Tiềm Năng: Thiếu Lâm/Thiên Vương nâng Sức Mạnh & Thể Lực; Nga Mi/Thúy Yên ưu tiên Nội Công; Đường Môn cần Thân Pháp.",
		"Vượt Ải Khiêu Chiến: Ải càng cao, tốc độ thu thập Bạc và Exp mỗi phút càng gia tăng vượt trội.",
		"Trang Bị Hoàng Kim: Vượt các mốc Ải Thách Đấu lớn và săn Boss Tinh Anh để thu thập mảnh trang bị Hoàng Kim môn phái.",
		"Đồng Hành Cùng Hệ: Triệu hoán các hiệp khách đồng hành cùng hệ Ngũ Hành sẽ kích hoạt Hào Quang trận pháp toàn đội.",
		"Nhiệm Vụ Dã Tẩu: Hoàn thành 10 lượt nhiệm vụ Dã Tẩu mỗi ngày để nhận vô số Bạc, Huyền Tinh và Vé Tầm Bảo.",
		"Tẩy Luyện Thuộc Tính: Ưu tiên giữ lại các dòng chỉ số quý như: Bạo Kích, Hút Sinh Lực, Bỏ Qua Kháng và Kháng Tất Cả.",
		"Tự Động Chiến Đấu: Bạn có thể bật Auto xuất chiêu để nhân vật tự động cày cuốc bí kíp khi bận rộn.",
		"Tâm Pháp Trấn Phái: Nâng cấp kỹ năng trấn phái giúp gia tăng vĩnh viễn uy lực tất cả chiêu thức của bổn môn.",
		"Boss Thế Giới: Tham gia săn Boss Hoàng Kim cùng huynh đệ Bang Hội mỗi ngày để nhận rương Thần Binh thượng phẩm.",
		"Thuộc Tính Âm Dương: Trang bị cùng bộ Hoàng Kim sẽ kích hoạt các dòng ẩn liên hoàn tăng vọt lực chiến.",
		"Bí Kíp Võ Công: Đột phá bí kíp lên tầng cao sẽ mở khóa thêm hiệu ứng khống chế diện rộng khi giao chiến.",
		"Tầm Bảo May Mắn: Tích lũy đủ 10 Vé Tầm Bảo để quay liên tiếp nhận tỷ lệ nhận Hiệp Khách Cam cao hơn."
	];

	// Khoi tao meo ngau nhien & quay vong
	let currentTipIndex = Math.floor(Math.random() * TIPS.length);
	const tipElement = document.getElementById('tip-text');
	if (tipElement) {
		tipElement.textContent = TIPS[currentTipIndex];
	}

	const tipInterval = setInterval(function () {
		if (!tipElement) return;
		tipElement.classList.add('fade-out');
		setTimeout(function () {
			let nextIndex;
			do {
				nextIndex = Math.floor(Math.random() * TIPS.length);
			} while (nextIndex === currentTipIndex && TIPS.length > 1);
			currentTipIndex = nextIndex;
			tipElement.textContent = TIPS[currentTipIndex];
			tipElement.classList.remove('fade-out');
			tipElement.classList.add('fade-in');
			setTimeout(function () {
				tipElement.classList.remove('fade-in');
			}, 400);
		}, 350);
	}, 4200);

	// Nếu là thiết bị di động / máy tính bảng: Ngăn chặn tải game hoàn toàn
	if (window.__IS_MOBILE_DEVICE) {
		if (typeof tipInterval !== 'undefined') clearInterval(tipInterval);
		const mobOverlay = document.getElementById('mobile-block-overlay');
		if (mobOverlay) mobOverlay.style.display = 'flex';
		const statusEl = document.getElementById('status');
		if (statusEl) statusEl.style.display = 'none';
		const canvasEl = document.getElementById('canvas');
		if (canvasEl) canvasEl.style.display = 'none';
		return;
	}

	const statusOverlay = document.getElementById('status');
	const progressBarFill = document.getElementById('progress-bar-fill');
	const progressPercent = document.getElementById('progress-percent');
	const progressBytes = document.getElementById('progress-bytes');
	const progressState = document.getElementById('progress-state');
	const statusNotice = document.getElementById('status-notice');

	let initializing = true;

	function formatBytes(bytes) {
		if (!bytes || bytes <= 0) return '0 MB';
		if (bytes >= 1073741824) {
			return (bytes / 1073741824).toFixed(2) + ' GB';
		}
		return (bytes / 1048576).toFixed(1) + ' MB';
	}

	function updateProgressUI(current, total) {
		if (total > 0) {
			const pct = Math.min(100, Math.max(0, Math.floor((current / total) * 100)));
			if (progressBarFill) progressBarFill.style.width = pct + '%';
			if (progressPercent) progressPercent.textContent = pct + '%';
			if (progressBytes) progressBytes.textContent = formatBytes(current) + ' / ' + formatBytes(total);
			if (progressState) {
				if (window.__IS_FROM_SSD) {
					progressState.textContent = '⚡ Đang nạp từ bộ nhớ SSD (' + pct + '%)';
				} else {
					progressState.textContent = 'Đang tải tài nguyên Võ Lâm (' + pct + '%)';
				}
			}
		}
	}

	function setStatusNotice(text) {
		while (statusNotice.lastChild) {
			statusNotice.removeChild(statusNotice.lastChild);
		}
		const lines = text.split('\\n');
		lines.forEach((line) => {
			statusNotice.appendChild(document.createTextNode(line));
			statusNotice.appendChild(document.createElement('br'));
		});
	}

	function showInAppBrowserNotice() {
		initializing = false;
		const progressBox = document.querySelector('.progress-box');
		if (progressBox) progressBox.style.display = 'none';
		const cacheNotice = document.querySelector('.cache-notice');
		if (cacheNotice) cacheNotice.style.display = 'none';
		const tipsBox = document.querySelector('.tips-box');
		if (tipsBox) tipsBox.style.display = 'none';

		statusNotice.style.display = 'block';
		statusNotice.style.background = '#181b22';
		statusNotice.style.border = '2px solid #ffd700';
		statusNotice.style.borderRadius = '14px';
		statusNotice.style.maxWidth = '440px';
		statusNotice.style.padding = '22px 18px';
		statusNotice.style.margin = '20px auto';
		statusNotice.style.boxShadow = '0 12px 35px rgba(0, 0, 0, 0.9)';
		statusNotice.style.color = '#e0e0e0';

		const isAndroid = /Android/i.test(navigator.userAgent);
		const intentUrl = 'intent://' + window.location.host + window.location.pathname + window.location.search + '#Intent;scheme=https;action=android.intent.action.VIEW;end';

		statusNotice.innerHTML = `
			<div style="font-size: 36px; margin-bottom: 8px;">⚔️</div>
			<div style="color: #ffd700; font-size: 18px; font-weight: bold; margin-bottom: 12px; letter-spacing: 0.5px;">
				YÊU CẦU MỞ BẰNG TRÌNH DUYỆT NGOÀI
			</div>
			<div style="font-size: 13.5px; line-height: 1.6; margin-bottom: 14px; text-align: left; color: #cfd8dc;">
				Bạn đang mở game qua trình duyệt nội bộ của <b>Messenger / Zalo / Facebook</b>. Các trình duyệt này hạn chế tính năng WebAssembly để bảo mật.
			</div>
			<div style="background: rgba(255,255,255,0.06); border-radius: 8px; padding: 12px 14px; margin-bottom: 16px; text-align: left; font-size: 13px; line-height: 1.8; color: #fff; border-left: 3px solid #ffd700;">
				<div>👉 <b>Bước 1:</b> Nhấn vào biểu tượng <b>··· (3 chấm)</b> ở góc trên bên phải.</div>
				<div>👉 <b>Bước 2:</b> Chọn <b>"Mở trong trình duyệt hệ thống"</b> (hoặc <b>"Mở trong Chrome / Safari"</b>).</div>
			</div>
			${isAndroid ? `
			<a href="${intentUrl}" style="display: block; background: linear-gradient(135deg, #ffd700, #ff9800); color: #000; font-weight: bold; font-size: 15px; padding: 12px 18px; border-radius: 8px; text-decoration: none; box-shadow: 0 4px 12px rgba(255,152,0,0.4); margin-bottom: 6px;">
				🚀 Mở ngay bằng Google Chrome
			</a>
			` : `
			<div style="color: #ffb74d; font-size: 13px; font-style: italic;">
				🍎 <i>Trên iPhone/iPad: Vui lòng chọn "Mở trong Safari" để chơi game.</i>
			</div>
			`}
		`;
	}

	function displayFailureNotice(err) {
		if (err instanceof Error) {
			setStatusNotice(err.message);
		} else if (typeof err === 'string') {
			setStatusNotice(err);
		} else {
			setStatusNotice('Đã xảy ra lỗi không xác định khi tải game.');
		}
		statusNotice.style.display = 'block';
		initializing = false;
	}

	// Tu dong don sach console lien tuc
	const consoleCleaner = setInterval(function () {
		try { window.console.clear(); } catch (e) {}
	}, 1500);

	const missing = Engine.getMissingFeatures({
		threads: GODOT_THREADS_ENABLED,
	});

	if (missing.length !== 0) {
		if (GODOT_CONFIG['serviceWorker'] && GODOT_CONFIG['ensureCrossOriginIsolationHeaders'] && 'serviceWorker' in navigator) {
			let serviceWorkerRegistrationPromise;
			try {
				serviceWorkerRegistrationPromise = navigator.serviceWorker.getRegistration();
			} catch (err) {
				serviceWorkerRegistrationPromise = Promise.reject(new Error('Service worker registration failed.'));
			}
			Promise.race([
				serviceWorkerRegistrationPromise.then((registration) => {
					if (registration != null) {
						return Promise.reject(new Error('Service worker already exists.'));
					}
					return registration;
				}).then(() => engine.installServiceWorker()),
				new Promise((resolve) => {
					setTimeout(() => resolve(), 2000);
				}),
			]).then(() => {
				window.location.reload();
			}).catch(() => {});
		} else {
			const missingMsg = 'Lỗi tương thích:\\nTrình duyệt cần hỗ trợ WebAssembly và SharedArrayBuffer để chạy game.\\n' + missing.join('\\n');
			displayFailureNotice(missingMsg);
		}
	} else {
		
window.__CONTENT_PCK_STATUS = {
	loaded: 0,
	total: __CONTENT_SIZE__,
	percent: 0,
	speed: '',
	is_ready: false,
	error: null
};

async function startBackgroundContentDownload(engineInstance) {
	const CACHE_NAME = 'jx1-content-cache-v1';
	const CONTENT_URL = 'content.pck?v=__CONTENT_VERSION__';
	
	try {
		if ('caches' in window) {
			const cache = await caches.open(CACHE_NAME);
			const cachedResp = await cache.match(CONTENT_URL);
			if (cachedResp) {
				window.__CONTENT_PCK_STATUS.speed = '⚡ SSD';
				window.__CONTENT_PCK_STATUS.percent = 80;
				const buf = await cachedResp.arrayBuffer();
				window.__CONTENT_PCK_STATUS.loaded = buf.byteLength;
				window.__CONTENT_PCK_STATUS.total = buf.byteLength;
				window.__CONTENT_PCK_STATUS.percent = 100;
				_injectContentPack(engineInstance, buf);
				return;
			}
		}
	} catch (e) {}

	try {
		window.__CONTENT_PCK_STATUS.speed = 'Đang kết nối...';
		const resp = await fetch(CONTENT_URL);
		if (!resp.ok) throw new Error('HTTP ' + resp.status);
		
		const clen = parseInt(resp.headers.get('content-length') || '__CONTENT_SIZE__', 10);
		window.__CONTENT_PCK_STATUS.total = clen;
		
		const reader = resp.body.getReader();
		const chunks = [];
		let loaded = 0;
		let lastT = performance.now();
		let lastL = 0;

		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			chunks.push(value);
			loaded += value.length;
			
			const now = performance.now();
			if (now - lastT >= 400) {
				const spd = ((loaded - lastL) / (now - lastT)) * 1000;
				window.__CONTENT_PCK_STATUS.speed = (spd / 1048576).toFixed(1) + ' MB/s';
				lastT = now;
				lastL = loaded;
			}
			
			window.__CONTENT_PCK_STATUS.loaded = loaded;
			if (clen > 0) {
				window.__CONTENT_PCK_STATUS.percent = Math.min(99, Math.floor((loaded / clen) * 100));
			}
		}

		const full = new Uint8Array(loaded);
		let off = 0;
		for (const ch of chunks) {
			full.set(ch, off);
			off += ch.length;
		}
		const finalBuf = full.buffer;

		try {
			if ('caches' in window) {
				const cache = await caches.open(CACHE_NAME);
				const keys = await cache.keys();
				for (const k of keys) {
					if (k.url.includes('content.pck')) await cache.delete(k);
				}
				await cache.put(CONTENT_URL, new Response(full, {
					headers: {
						'content-type': 'application/octet-stream',
						'content-length': String(loaded)
					}
				}));
			}
		} catch (e) {}

		_injectContentPack(engineInstance, finalBuf);
	} catch (err) {
		window.__CONTENT_PCK_STATUS.error = err.message;
		window.__CONTENT_PCK_STATUS.speed = 'Lỗi nạp';
	}
}

function _injectContentPack(engineInstance, buf) {
	function doCopy() {
		try {
			if (engineInstance && engineInstance.copyToFS) {
				engineInstance.copyToFS('content.pck', buf);
				window.__CONTENT_PCK_STATUS.percent = 100;
				window.__CONTENT_PCK_STATUS.is_ready = true;
				window.__CONTENT_PCK_STATUS.speed = 'Sẵn sàng';
				return;
			}
		} catch (e) {}
		setTimeout(doCopy, 200);
	}
	doCopy();
}

		engine.startGame({
			'onProgress': function (current, total) {
				updateProgressUI(current, total);
			},
			'onPrint': function () {},
			'onPrintError': function () {}
		}).then(() => {
			startBackgroundContentDownload(engine);
			if (progressBarFill) progressBarFill.style.width = '100%';
			if (progressPercent) progressPercent.textContent = '100%';
			if (progressState) progressState.textContent = 'Khởi động Võ Lâm...';

			clearInterval(tipInterval);
			setTimeout(function () {
				clearInterval(consoleCleaner);
				try { window.console.clear(); } catch (e) {}
				if (statusOverlay) {
					statusOverlay.style.opacity = '0';
					statusOverlay.style.pointerEvents = 'none';
					setTimeout(() => {
						try { statusOverlay.remove(); } catch (e) {}
					}, 650);
				}
			}, 300);
			initializing = false;
		}, displayFailureNotice);
	}
})();
		</script>
	</body>
</html>
"""

html_content = (TEMPLATE
    .replace("__PCK_SIZE__", str(pck_size))
    .replace("__WASM_SIZE__", str(wasm_size))
    .replace("__BUILD_VERSION__", str(build_version))
    .replace("__WASM_VERSION__", str(wasm_version))
    .replace("__CONTENT_SIZE__", str(content_size))
    .replace("__CONTENT_VERSION__", str(content_version))
)

with open(index_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[*] Da cap nhat Loading UI wuxia + OPFS Cache + Tat Console Logs cho {index_path} (PCK: {pck_size} B, WASM: {wasm_size} B)")


# Dong bo index.js on dinh chuan tu Godot official template
js_file = os.path.join(web_dir, "index.js")
zip_path = os.path.expandvars(r'%APPDATA%\Godot\export_templates\4.7.2.stable\web_release.zip')
if os.path.exists(zip_path) and os.path.exists(js_file):
    try:
        import zipfile
        with zipfile.ZipFile(zip_path, 'r') as z:
            with open(js_file, 'wb') as f:
                f.write(z.read('godot.js'))
        print('[*] Da dong bo index.js chuan Godot Engine (khong bi patch hu hong).')
    except Exception as e:
        print(f'[!] Khong the dong bo index.js: {e}')
