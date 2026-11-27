"""Ảnh THANH DƯỚI bản web lấy nguyên từ giao diện 1024x768 của client VLTK 15 phái (data/1024.pak).

Gốc: \\Ui\\Ui3\\UiPlayerBar.ini trong 1024.pak (đọc theo mã băm) — [Main] Image = \\spr\\Ui3\\thanhcongcu\\jx1024.spr (1024x769):
  ô nhập chat [InputBack] \\Spr\\UI3\\主界面\\聊天输入条.spr (134,688) · [Face] \\Spr\\Ui3\\表情\\01.spr (416,690)
  · [SendBtn] \\Spr\\Ui3\\主界面\\主界面按钮-聊天发送.spr (439,690) · 9 ô [Item_0..8] (136+38i, 719) 36x36
  · 2 ô skill [ImediaLeftSkill/RightSkill] (492,697) / (529,697) · [Friend] (735,728) · [Options] (859,728) · [Market] (876,680).
Thanh công cụ bên phải: [Main] ToolBoxSchema = 工具控制条.ini (cũng trong 1024.pak) — Button0..14, ảnh \\spr\\UI3\\主界面\\*.spr
(3 khung thường / bấm / rê chuột; nút bật-tắt 2 khung). Toạ độ trong web_hud_bar.gd tính theo gốc cắt (0, TOP).

    python tools/import_vltk_web_bar.py      -> assets/ui/web_bar/*.png
"""
import os
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import spr_to_png  # noqa: E402
import vltk_pak  # noqa: E402
import vltk_source  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(HERE), "assets", "ui", "web_bar")
BAR_SPR = "spr/Ui3/thanhcongcu/jx1024.spr"
SPRITES = {
	"input_back": "Spr/UI3/主界面/聊天输入条.spr",
	"face": "Spr/Ui3/表情/01.spr",
	"send": "Spr/Ui3/主界面/主界面按钮-聊天发送.spr",
}
TOP = 672          ## đỉnh khung T/P trong ảnh 1024x769 (hàng nút tròn y=675 vẫn nằm trong)
## Nút thanh công cụ (工具控制条.ini + [Friend] / [Options] / [Market] của UiPlayerBar.ini) -> tên file ảnh gốc.
BUTTONS = {
	"status": "人物属性按钮_0", "items": "背包按钮", "itemex": "子母袋按钮", "skills": "技能按钮", "task": "任务按钮",
	"team": "队伍按钮", "faction": "帮会按钮", "chatroom": "聊天室按钮", "run": "跑步按钮", "sit": "打坐按钮",
	"horse": "骑马按钮", "exchange": "交易按钮", "pk": "PK按钮", "rec": "摄像机按钮", "friend": "人际关系按钮",
	"options": "系统按钮", "market": "奇珍阁按钮_vn",
}

## Ảnh nút kênh (UiMsgCentrePad.ini: [CH_*] MenuImage, [MSNRoom] Stranger_MenuImage) — nút chọn kênh trên thanh dưới (gốc
## KUiPlayerBar::SetCurrentChannel gắn ảnh nhúng nMenuPicIndex vào [ChannelBtn]) + ô chọn kênh của khung chat.
## Tên theo mã kênh của game (ChatServer: 0 Gần, 1 Thế giới, 2 Tổ đội, 3 Bang hội, 4 Riêng, 5 Môn phái) + "system" (Hệ thống / GM).
CHANNEL_SPRITES = {
	"ch_0": "主界面按钮-附近频道选择",      ## CH_NEARBY
	"ch_1": "主界面按钮-世界频道选择",      ## CH_WORLD
	"ch_2": "主界面按钮-队伍频道选择",      ## CH_TEAM
	"ch_3": "帮会聊天频道选择",             ## CH_TONG
	"ch_4": "主界面按钮-密人频道选择",      ## MSNRoom Stranger (nhắn riêng)
	"ch_5": "主界面按钮-门派频道选择",      ## CH_FACTION
	"ch_system": "主界面按钮-GM频道选择",   ## CH_SYSTEM
}

## Ảnh đầu dòng tin trong khung chat (UiMsgCentrePad.ini [CH_*] TextImage, [MSNRoom] Self_/Stranger_TextImage) — gốc chèn ảnh nhúng
## nTextPicIndex trước tên người gửi (KUiMsgCentrePad::ChannelMessageArrival / ShowMSNMessage).
CHANNEL_TEXT_SPRITES = {
	"chtx_0": "聊天频道图示－附近频道",
	"chtx_1": "聊天频道图示－世界频道",
	"chtx_2": "聊天频道图示－队伍频道",
	"chtx_3": "聊天频道图示－帮派频道",
	"chtx_4": "聊天频道图示－密人频道",
	"chtx_5": "聊天频道图示－门派频道",
	"chtx_system": "聊天频道图示－GM频道",
	"chtx_self": "聊天频道图示－自己说",
}


def _read(paks, path):
	data = paks.read(path)
	if data is None:
		raise SystemExit("THIẾU " + path)
	tmp = os.path.join(tempfile.mkdtemp(), "x.spr")
	with open(tmp, "wb") as f:
		f.write(data)
	images, _meta = spr_to_png.read_spr(tmp)
	return [im.convert("RGBA") for im in images]


def _save(im, name):
	im.save(os.path.join(OUT_DIR, name), optimize=True)
	print("%s %dx%d" % (name, im.size[0], im.size[1]))


def export_channels(paks):
	for name, file in CHANNEL_SPRITES.items():
		for i, im in enumerate(_read(paks, "spr/UI3/主界面/%s.spr" % file)[:3]):
			_save(im, "%s_%d.png" % (name, i))
	for name, file in CHANNEL_TEXT_SPRITES.items():
		_save(_read(paks, "spr/UI3/主界面/%s.spr" % file)[0], "%s.png" % name)


def main():
	os.makedirs(OUT_DIR, exist_ok=True)
	## package1.ini đặt 1024.pak ngay sau jxthaipham.pak -> đọc đúng bản giao diện 1024x768.
	paks = vltk_pak.PakList(str(vltk_source.CLIENT), "package1.ini")
	full = _read(paks, BAR_SPR)[0]
	_save(full.crop((0, TOP, full.width, full.height)), "bar.png")
	for name, path in SPRITES.items():
		for i, im in enumerate(_read(paks, path)[:3]):
			_save(im, "%s_%d.png" % (name, i))
	for name, file in BUTTONS.items():
		for i, im in enumerate(_read(paks, "spr/UI3/主界面/%s.spr" % file)[:3]):
			_save(im, "btn_%s_%d.png" % (name, i))
	export_channels(paks)


if __name__ == "__main__":
	if "--channels" in sys.argv:   ## chỉ xuất ảnh nút kênh
		os.makedirs(OUT_DIR, exist_ok=True)
		export_channels(vltk_pak.PakList(str(vltk_source.CLIENT), "package1.ini"))
	else:
		main()
