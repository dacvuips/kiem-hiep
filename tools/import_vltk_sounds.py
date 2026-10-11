"""Nhập ÂM THANH VLTK gốc: âm UI, âm ra chiêu / đạn của skill, âm quái, nhạc nền theo map.

    python tools/import_vltk_sounds.py

Nguồn (theo mã nguồn gốc Core/Src):
  - UI: settings/SoundList.txt ([Ui], [Game]) — client VNG (pak).
  - Ra chiêu: settings/skills.txt cột ManCastSnd / FMCastSnd (KSkill::PlayPreCastSound — nam/nữ), client VNG (pak).
  - Đạn: settings/missles.txt cột SndFile1..4 (KMissleRes: 1=chờ, 2=bay, 3=tan biến, 4=va chạm) và SndFileB1..4 (biến thể B).
  - Nhân vật chính: client settings/npcres/主角动作声音表.txt (tiếng đánh tay/vũ khí, chạy, bị đánh, chết, nhảy, cưỡi ngựa — nam/nữ).
  - Quái: client settings/npcres/npc动作声音表.txt (KNpcResNode: hàng = bộ tài nguyên quái, cột = động tác như
    phát khi bắt đầu động tác, KNpcRes::PlaySound), file âm trong sound.pak.
  - Nhạc: server settings/Music/MusicSet.txt (Map ID -> bài, âm lượng) + MusicFightSet.ini (nhóm bài theo vùng).
    File .mp3 trong thư mục music của client VLTK.
Đầu ra:
  audio/vltk/sound/...wav   (chỉ file được tham chiếu và có trong pak; file thiếu trong pak gốc thì bỏ qua)
  audio/vltk/music/*.mp3
  data/sound/vltk_sounds.json  {ui, game, skills, missiles, player, npc, music_map, music_fight}
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import vltk_pak  # noqa: E402

VNG = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
CLIENT = r"D:\game\source_vo-lam-truyen-ky\Client_VLTK\Client_VLTK"
SERVER = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_SOUND = os.path.join(ROOT, "audio", "vltk", "sound")
OUT_MUSIC = os.path.join(ROOT, "audio", "vltk", "music")
OUT_JSON = os.path.join(ROOT, "data", "sound", "vltk_sounds.json")

ACTIONS = ["fight_stand", "stand1", "stand2", "fight_walk", "walk", "fight_run", "run", "hurt", "die", "attack1",
           "attack2", "magic", "sit", "jump"]
MISSILE_PHASES = ["wait", "fly", "vanish", "collision"]

pl = vltk_pak.PakList.__new__(vltk_pak.PakList)
pl.client_dir, pl.paks = VNG, []
for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
	pl.paks.append(vltk_pak.PakFile(os.path.join(VNG, "data", n + ".pak")))

STEP_TABLE = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
	107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
	1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
	7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
INDEX_TABLE = [-1, -1, -1, -1, 2, 4, 6, 8]


def wav_chunks(data: bytes):
	i = 12
	while i < len(data) - 8:
		cid, size = data[i:i + 4], struct.unpack("<I", data[i + 4:i + 8])[0]
		yield cid, data[i + 8:i + 8 + size]
		i += 8 + size + (size & 1)


def ima_adpcm_to_pcm(data: bytes) -> bytes:
	"""Godot không đọc WAV ADPCM — giải mã IMA ADPCM (format 0x11) sang PCM 16-bit."""
	fmt = pcm = None
	for cid, body in wav_chunks(data):
		if cid == b"fmt ":
			fmt = struct.unpack("<HHIIHH", body[:16])
		elif cid == b"data":
			pcm = body
	tag, channels, rate, _, block_align, _ = fmt
	out = bytearray()
	for b in range(0, len(pcm), block_align):
		block = pcm[b:b + block_align]
		if len(block) < 4 * channels:
			break
		chans = []
		for ch in range(channels):
			predictor, index = struct.unpack("<hB", block[ch * 4:ch * 4 + 3])
			chans.append([predictor, min(index, 88), [predictor]])
		body = block[4 * channels:]
		# dữ liệu xen kẽ theo từng nhóm 4 byte (8 mẫu) cho mỗi kênh
		for g in range(0, len(body) - 4 * channels + 1, 4 * channels):
			for ch in range(channels):
				state = chans[ch]
				for byte in body[g + ch * 4:g + ch * 4 + 4]:
					for nib in (byte & 15, byte >> 4):
						step = STEP_TABLE[state[1]]
						diff = step >> 3
						if nib & 1:
							diff += step >> 2
						if nib & 2:
							diff += step >> 1
						if nib & 4:
							diff += step
						state[0] = max(-32768, min(32767, state[0] - diff if nib & 8 else state[0] + diff))
						state[1] = max(0, min(88, state[1] + INDEX_TABLE[nib & 7]))
						state[2].append(state[0])
		n = min(len(c[2]) for c in chans)
		for i in range(n):
			for c in chans:
				out += struct.pack("<h", c[2][i])
	header = b"RIFF" + struct.pack("<I", 36 + len(out)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, channels, rate, rate * channels * 2, channels * 2, 16)
	return header + b"data" + struct.pack("<I", len(out)) + bytes(out)


def mp3_from_wav(data: bytes):
	"""WAV định dạng 0x55 (MPEG Layer 3) -> byte MP3 thô (khối `data`); None nếu không phải."""
	for cid, body in wav_chunks(data):
		if cid == b"fmt ":
			if struct.unpack("<H", body[:2])[0] != 0x55:
				return None
		elif cid == b"data":
			return bytes(body)
	return None


def to_pcm_wav(data: bytes) -> bytes:
	for cid, body in wav_chunks(data):
		if cid == b"fmt ":
			tag = struct.unpack("<H", body[:2])[0]
			if tag == 1 or tag == 3:
				return data
			if tag == 0x11:
				return ima_adpcm_to_pcm(data)
			print("  CẢNH BÁO: WAV định dạng", tag, "chưa hỗ trợ — bỏ qua")
			return b""
	return data


alias: dict = {}    # đường dẫn .wav gốc -> .mp3 đã tách
copied: dict = {}   # đường dẫn trong game ("skill/sound_k001.wav") -> True/False
missing: set = set()


def _find_iconv() -> str:
	"""iconv có sẵn trong Git for Windows nhưng PowerShell/cmd thường không có trong PATH -> thử các chỗ quen thuộc."""
	found = shutil.which("iconv")
	if found:
		return found
	for cand in (r"C:\Program Files\Git\usr\bin\iconv.exe", r"C:\Program Files (x86)\Git\usr\bin\iconv.exe",
			r"D:\PhanMem\GitBash\usr\bin\iconv.exe"):
		if os.path.isfile(cand):
			return cand
	sys.exit("Không tìm thấy iconv — cài Git for Windows hoặc thêm thư mục usr\\bin của nó vào PATH.")


ICONV = _find_iconv()


def tcvn_table(raw: bytes):
	text = subprocess.run([ICONV, "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=raw, capture_output=True).stdout.decode("utf-8", "replace")
	lines = text.split("\n")
	header = [h.strip("\ufeff \r") for h in lines[0].split("\t")]
	return header, [dict(zip(header, l.rstrip("\r").split("\t"))) for l in lines[1:] if l.strip()]


def gbk_table(raw: bytes):
	"""Bảng skills/missles của VNG: tên file âm thanh trong pak là tiếng Trung (GBK) nên PHẢI giải mã GBK — giải mã TCVN3 làm hỏng
	tên và không tra được file (hàng loạt skill/đạn mất tiếng). Cột chữ Việt (tên/mô tả) không dùng ở đây nên mặc kệ."""
	NL, TAB, CR = chr(10), chr(9), chr(13)
	lines = raw.split(NL.encode())
	header = [h.decode("gbk", "replace").strip(chr(0xFEFF) + " " + CR) for h in lines[0].split(TAB.encode())]
	return header, [dict(zip(header, l.decode("gbk", "replace").rstrip(CR).split(TAB))) for l in lines[1:] if l.strip()]


def sound(ref: str):
	"""Chuẩn hoá tham chiếu âm (dạng /Sound/skill/x.wav hoặc x.wav) -> đường dẫn tương đối trong audio/vltk/sound, hoặc None."""
	ref = ref.strip().replace("\\", "/")
	if not ref:
		return None
	low = ref.lower()
	if low.startswith("/"):
		low = low[1:]
	if not low.startswith("sound/"):
		low = "sound/" + low
	rel = low[len("sound/"):]
	if rel in alias:
		return alias[rel]
	if rel in copied:
		return rel if copied[rel] else None
	try:
		data = pl.read(low)
	except UnicodeEncodeError:  # tên file lẫn ký tự lạ do giải mã TCVN3
		data = None
	if data is None:
		copied[rel] = False
		missing.add(rel)
		return None
	mp3 = mp3_from_wav(data)
	if mp3 is not None:  # WAV chứa MP3 (định dạng 0x55): tách khung MP3, Godot đọc được .mp3
		rel = rel[:-4] + ".mp3"
		dest = os.path.join(OUT_SOUND, *rel.split("/"))
		os.makedirs(os.path.dirname(dest), exist_ok=True)
		with open(dest, "wb") as f:
			f.write(mp3)
		copied[rel] = True
		copied[low[len("sound/"):]] = True
		alias[low[len("sound/"):]] = rel
		return rel
	data = to_pcm_wav(data)
	if not data:
		copied[rel] = False
		missing.add(rel)
		return None
	dest = os.path.join(OUT_SOUND, *rel.split("/"))
	os.makedirs(os.path.dirname(dest), exist_ok=True)
	with open(dest, "wb") as f:
		f.write(data)
	copied[rel] = True
	return rel


out: dict = {}

# ---- UI / game (SoundList.txt, TCVN3 + chú thích) ----
section, ui_game = None, {}
for line in pl.read("settings/SoundList.txt").decode("latin1").split("\n"):
	line = line.strip()
	if not line or line.startswith(";"):
		continue
	m = re.match(r"^\[(\w+)\]$", line)
	if m:
		section = m.group(1).lower()
		ui_game[section] = {}
		continue
	m = re.match(r"^(\d+)\s*=\s*(.+)$", line)
	if m and section:
		rel = sound(m.group(2))
		if rel:
			ui_game[section][m.group(1)] = rel
out.update(ui_game)

# ---- Skill ra chiêu ----
_, rows = gbk_table(pl.read("settings/skills.txt"))
skills = {}
for r in rows:
	sid = r.get("SkillId", "").strip()
	if not sid.isdigit():
		continue
	man, fm = sound(r.get("ManCastSnd", "")), sound(r.get("FMCastSnd", ""))
	if man or fm:
		skills[sid] = {k: v for k, v in (("man", man), ("fm", fm or man)) if v}
out["skills"] = skills

# ---- Đạn ----
_, rows = gbk_table(pl.read("settings/missles.txt"))
missiles = {}
for r in rows:
	mid = r.get("MissleId", r.get("MissileId", "")).strip()
	if not mid.isdigit():
		continue
	entry = {}
	for suffix, tag in (("", "a"), ("B", "b")):
		phases = {}
		for i, phase in enumerate(MISSILE_PHASES, 1):
			rel = sound(r.get("SndFile%s%d" % (suffix, i), ""))
			if rel:
				phases[phase] = rel
		if phases:
			entry[tag] = phases
	if entry:
		missiles[mid] = entry
out["missiles"] = missiles

# ---- Quái (bảng động tác - âm thanh) ----
npc_dir = os.path.join(CLIENT, "settings", "npcres")
tbl = None
for f in os.listdir(npc_dir):
	try:
		name = f.encode("cp1252").decode("gbk")
	except (UnicodeEncodeError, UnicodeDecodeError):
		name = f
	if name.lower().startswith("npc") and "\u58f0\u97f3" in name:
		tbl = os.path.join(npc_dir, f)
npc = {}
for line in open(tbl, "rb").read().decode("gbk", "replace").split("\n")[1:]:
	cells = line.rstrip("\r").split("\t")
	if len(cells) < 2 or not cells[0].strip():
		continue
	acts = {}
	for action, cell in zip(ACTIONS, cells[1:]):
		rel = sound(cell)
		if rel:
			acts[action] = rel
	if acts:
		npc[cells[0].strip().lower()] = acts
out["npc"] = npc

# ---- Nhân vật chính (bảng 主角动作声音表: hàng = động tác gốc như FreeAttack/MeleeWCut/RideRun, cột = nam / nữ) ----
player_tbl = None
for f in os.listdir(npc_dir):
	try:
		name = f.encode("cp1252").decode("gbk")
	except (UnicodeEncodeError, UnicodeDecodeError):
		name = f
	if "声音表" in name and not name.lower().startswith("npc"):
		player_tbl = os.path.join(npc_dir, f)
player = {}
for line in open(player_tbl, "rb").read().decode("gbk", "replace").split("\n")[1:]:
	cells = line.rstrip("\r").split("\t")
	if len(cells) < 3 or not cells[0].strip():
		continue
	man, fm = sound(cells[1]), sound(cells[2])
	if man or fm:
		player[cells[0].strip()] = {"man": man or fm, "fm": fm or man}
out["player"] = player

# ---- Nhạc ----
os.makedirs(OUT_MUSIC, exist_ok=True)
music_used = set()


def music(ref: str):
	name = os.path.basename(ref.strip().replace("\\", "/")).lower()
	if not name.endswith(".mp3"):
		return None
	src = os.path.join(CLIENT, "music", name)
	if not os.path.isfile(src):
		return None
	if name not in music_used:
		shutil.copyfile(src, os.path.join(OUT_MUSIC, name))
		music_used.add(name)
	return name


music_map = {}
lines = open(os.path.join(SERVER, "settings", "Music", "MusicSet.txt"), "rb").read().decode("gbk", "replace").split("\n")
for line in lines[1:]:
	c = line.rstrip("\r").split("\t")
	if not c[0].strip().isdigit():
		continue
	tracks = []
	for i in range(0, 4):
		base = 1 + i * 5
		if base < len(c) and c[base].strip():
			name = music(c[base])
			if name:
				tracks.append({"file": name, "volume": int(c[base + 1] or 93)})
	if tracks:
		music_map[c[0].strip()] = tracks
out["music_map"] = music_map

fight, stage = {}, None
for line in open(os.path.join(SERVER, "settings", "Music", "MusicFightSet.ini"), "rb").read().decode("gbk", "replace").split("\n"):
	line = line.strip()
	m = re.match(r"^\[Stage(\d+)\]$", line)
	if m:
		stage = fight.setdefault(m.group(1), {"maps": [], "tracks": []})
		continue
	m = re.match(r"^Map\d+=(\d+)$", line)
	if m and stage is not None:
		stage["maps"].append(int(m.group(1)))
	m = re.match(r"^Music\d+=(.+)$", line)
	if m and stage is not None:
		name = music(m.group(1))
		if name:
			stage["tracks"].append(name)
out["music_fight"] = fight

os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
with open(OUT_JSON, "w", encoding="utf-8") as f:
	json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
ok = sum(1 for v in copied.values() if v)
print("âm thanh đã chép:", ok, "| thiếu trong pak gốc:", len(missing), "| nhạc:", len(music_used))
print("động tác nhân vật có tiếng:", len(player), "| skill:", len(skills), "| đạn:", len(missiles), "| bộ quái:", len(npc), "| map có nhạc:", len(music_map), "| vùng:", len(fight))
