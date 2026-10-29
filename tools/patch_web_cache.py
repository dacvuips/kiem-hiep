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
wasm_version = f"{wasm_size}_{wasm_mtime}" 

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
   ROTATE SCREEN OVERLAY (MOBILE PORTRAIT REMINDER)
   ======================================================== */
#rotate-overlay {
	display: none;
	position: fixed;
	top: 0;
	left: 0;
	right: 0;
	bottom: 0;
	width: 100%;
	height: 100%;
	background: radial-gradient(circle at 50% 36%, #1c140d 0%, #0d0a08 60%, #050403 100%);
	z-index: 100000;
	flex-direction: column;
	justify-content: center;
	align-items: center;
	text-align: center;
	padding: 24px;
	box-sizing: border-box;
}

@media screen and (orientation: portrait) and (max-width: 950px) {
	#rotate-overlay {
		display: flex !important;
	}
}

.rotate-card {
	display: flex;
	flex-direction: column;
	align-items: center;
	max-width: 360px;
	width: 90%;
	background: rgba(20, 14, 10, 0.92);
	border: 1.5px solid rgba(217, 178, 100, 0.55);
	border-radius: 16px;
	padding: 28px 20px;
	box-shadow: 0 10px 35px rgba(0, 0, 0, 0.85), 0 0 24px rgba(217, 178, 100, 0.2);
}

.rotate-icon-anim {
	font-size: 54px;
	margin-bottom: 16px;
	display: inline-block;
	animation: rotatePhoneAnim 2.8s ease-in-out infinite;
	filter: drop-shadow(0 0 16px rgba(245, 158, 11, 0.7));
}

@keyframes rotatePhoneAnim {
	0%, 20% { transform: rotate(0deg); }
	50%, 80% { transform: rotate(-90deg); }
	100% { transform: rotate(0deg); }
}

.rotate-title {
	font-family: 'Cinzel', 'Be Vietnam Pro', serif;
	font-size: 18px;
	font-weight: 700;
	color: #fbbf24;
	letter-spacing: 0.8px;
	margin-bottom: 10px;
	text-transform: uppercase;
	text-shadow: 0 0 10px rgba(251, 191, 36, 0.5);
}

.rotate-desc {
	font-size: 13px;
	line-height: 1.55;
	color: #d1c2ab;
	margin-bottom: 22px;
}

.btn-rotate-fs {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	gap: 8px;
	background: linear-gradient(135deg, #d97706 0%, #f59e0b 50%, #fbbf24 100%);
	color: #120b05;
	font-weight: 700;
	font-size: 14px;
	padding: 12px 22px;
	border-radius: 10px;
	border: 1px solid rgba(255, 255, 255, 0.4);
	cursor: pointer;
	box-shadow: 0 4px 15px rgba(245, 158, 11, 0.4);
	text-decoration: none;
	user-select: none;
}

.btn-rotate-fs:active {
	transform: scale(0.96);
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

		<!-- Màn hình thông báo xoay ngang điện thoại (Chỉ hiện khi cầm dọc trên mobile) -->
		<div id="rotate-overlay">
			<div class="rotate-card">
				<div class="rotate-icon-anim">📱</div>
				<div class="rotate-title">Vui Lòng Xoay Ngang Máy</div>
				<div class="rotate-desc">
					Để có tầm nhìn giang hồ bao quát và thao tác võ công thuận tiện nhất, đại hiệp hãy <strong>xoay ngang màn hình điện thoại</strong>.
				</div>
				<button class="btn-rotate-fs" onclick="window.enterLandscapeFullscreen()">
					<span>⛶</span> Toàn màn hình & Xoay ngay
				</button>
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
						<div class="cache-notice-title" id="cache-title">LƯU TRỮ VĨNH VIỄN TRÊN MÁY (SSD CACHE)</div>
						<div class="cache-notice-desc" id="cache-desc">
							Dữ liệu game (~1.1 GB) chỉ cần tải <strong>1 lần duy nhất</strong>. Từ lần vào sau, game sẽ khởi động tức thì trong chớp mắt mà không tốn dung lượng mạng!
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
// He thong Cache sieu toc: Su dung Origin Private File System (OPFS) cho 1.17GB PCK va CacheStorage cho 38MB WASM
window.__IS_FROM_SSD = false;

window.forceClearCacheAndReload = async function () {
	if (confirm('Xóa bộ nhớ đệm game trên máy và tải lại phiên bản mới nhất từ máy chủ?')) {
		try {
			if (navigator.storage && navigator.storage.getDirectory) {
				const root = await navigator.storage.getDirectory();
				for await (const name of root.keys()) {
					await root.removeEntry(name).catch(() => {});
				}
			}
			if ('caches' in window) {
				const keys = await caches.keys();
				for (const k of keys) await caches.delete(k);
			}
		} catch (e) {}
		window.location.reload(true);
	}
};

(function () {
	const BUILD_VERSION = "__BUILD_VERSION__";
	const WASM_VERSION = "__WASM_VERSION__";
	const PCK_SIZE = __PCK_SIZE__;
	const WASM_SIZE = __WASM_SIZE__;

	if (navigator.storage && navigator.storage.persist) {
		navigator.storage.persist().catch(() => {});
	}

	async function getCachedFile(fileName, expectedSize) {
		if (!navigator.storage || !navigator.storage.getDirectory) return null;
		try {
			const root = await navigator.storage.getDirectory();
			const handle = await root.getFileHandle(fileName, { create: false });
			const file = await handle.getFile();
			if (file && file.size === expectedSize) {
				return file;
			}
		} catch (e) {}
		return null;
	}

	async function streamAndSaveToOPFS(response, fileName) {
		if (!navigator.storage || !navigator.storage.getDirectory || !response.body) {
			return response;
		}
		try {
			const root = await navigator.storage.getDirectory();
			const handle = await root.getFileHandle(fileName, { create: true });
			const writable = await handle.createWritable();
			const reader = response.body.getReader();

			const stream = new ReadableStream({
				async start(controller) {
					try {
						while (true) {
							const { done, value } = await reader.read();
							if (done) {
								await writable.close();
								controller.close();
								break;
							}
							await writable.write(value);
							controller.enqueue(value);
						}
					} catch (err) {
						try { await writable.abort(); } catch (_) {}
						controller.error(err);
					}
				}
			});

			return new Response(stream, {
				status: response.status,
				statusText: response.statusText,
				headers: response.headers
			});
		} catch (e) {
			return response;
		}
	}

	const origFetch = window.fetch;
	window.fetch = async function (resource, init) {
		const url = typeof resource === 'string' ? resource : (resource && resource.url ? resource.url : '');

		// 1. Kiem tra index.pck (1.17GB) bang OPFS SSD (Co Versioning)
		if (url.includes('.pck')) {
			const pckName = 'index_' + BUILD_VERSION + '.pck';
			try {
				const file = await getCachedFile(pckName, PCK_SIZE);
				if (file) {
					window.__IS_FROM_SSD = true;
					const speedBadge = document.getElementById('progress-speed');
					if (speedBadge) speedBadge.textContent = '⚡ SSD Cực nhanh';
					const stateText = document.getElementById('progress-state');
					if (stateText) stateText.textContent = '⚡ Đang nạp từ bộ nhớ SSD...';
					const cacheTitle = document.getElementById('cache-title');
					if (cacheTitle) cacheTitle.textContent = '⚡ ĐANG NẠP TỪ BỘ NHỚ SSD MÁY';
					const cacheDesc = document.getElementById('cache-desc');
					if (cacheDesc) cacheDesc.innerHTML = 'Dữ liệu đã được lưu trên máy của bạn. Tốc độ đọc dữ liệu đạt mức tối đa, <strong>không tốn thêm lưu lượng mạng!</strong>';

					return new Response(file, {
						status: 200,
						statusText: 'OK',
						headers: {
							'Content-Type': 'application/octet-stream',
							'Content-Length': String(file.size)
						}
					});
				}
			} catch (e) {}

			// Tu dong don dep cac file pck phien ban cu trong OPFS de giai phong o dia
			try {
				if (navigator.storage && navigator.storage.getDirectory) {
					const root = await navigator.storage.getDirectory();
					for await (const name of root.keys()) {
						if ((name.startsWith('index_') && name !== pckName) || name === 'index.pck') {
							await root.removeEntry(name).catch(() => {});
						}
					}
				}
			} catch (e) {}

			const speedBadge = document.getElementById('progress-speed');
			if (speedBadge) speedBadge.textContent = '🌐 Đang tải bản mới';
			const fetchUrl = url + (url.includes('?') ? '&' : '?') + 'v=' + BUILD_VERSION;
			const resp = await origFetch(fetchUrl, init);
			if (resp && resp.ok) {
				return streamAndSaveToOPFS(resp, pckName);
			}
			return resp;
		}

		// 2. Kiem tra index.wasm (38MB) bang CacheStorage (Co Versioning)
		if (url.includes('.wasm')) {
			const wasmCacheKey = 'godot-wasm-' + WASM_VERSION;
			if ('caches' in window) {
				try {
					const cache = await caches.open(wasmCacheKey);
					const match = await cache.match(resource);
					if (match) {
						return match;
					}
					// Don dep cac cache wasm cu
					caches.keys().then((keys) => {
						keys.forEach((k) => {
							if (k.startsWith('godot-wasm-') && k !== wasmCacheKey) {
								caches.delete(k);
							}
						});
					});
					const fetchUrl = url + (url.includes('?') ? '&' : '?') + 'v=' + WASM_VERSION;
					const resp = await origFetch(fetchUrl, init);
					if (resp && resp.ok) {
						cache.put(resource, resp.clone()).catch(() => {});
					}
					return resp;
				} catch (e) {}
			}
		}

		return origFetch(resource, init);
	};
})();
		</script>
		<script src="index.js"></script>
		<script>
// Cau hinh Godot Engine & console muted
const GODOT_CONFIG = {
	"args": [],
	"canvasResizePolicy": 2,
	"emscriptenPoolSize": 8,
	"ensureCrossOriginIsolationHeaders": true,
	"executable": "index",
	"experimentalVK": false,
	"fileSizes": {"index.pck": __PCK_SIZE__, "index.wasm": __WASM_SIZE__},
	"focusCanvas": true,
	"gdextensionLibs": [],
	"godotPoolSize": 4,
	"onPrint": function () {},
	"onPrintError": function () {}
};
const GODOT_THREADS_ENABLED = true;
const engine = new Engine(GODOT_CONFIG);

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
		engine.startGame({
			'onProgress': function (current, total) {
				updateProgressUI(current, total);
			},
			'onPrint': function () {},
			'onPrintError': function () {}
		}).then(() => {
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
)

with open(index_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[*] Da cap nhat Loading UI wuxia + OPFS Cache + Tat Console Logs cho {index_path} (PCK: {pck_size} B, WASM: {wasm_size} B)")


# Tu dong patch index.js de chan GodotIME gay khoa ban phim tren mobile
js_file = os.path.join(web_dir, "index.js")
if os.path.exists(js_file):
    try:
        with open(js_file, "r", encoding="utf-8") as f:
            js_data = f.read()
        target_ime = "ime_active:function(active){"
        replace_ime = "ime_active:function(active){if('ontouchstart' in window||navigator.maxTouchPoints>0||/Android|iPhone|iPad|iPod/i.test(navigator.userAgent))return;"
        if target_ime in js_data and replace_ime not in js_data:
            js_data = js_data.replace(target_ime, replace_ime, 1)
            with open(js_file, "w", encoding="utf-8") as f:
                f.write(js_data)
            print("[*] Da tu dong patch index.js: vo hieu hoa GodotIME gay ket ban phim tren mobile.")
    except Exception as e:
        print(f"[!] Khong the patch index.js: {e}")
