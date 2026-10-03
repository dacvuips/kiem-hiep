"""Đọc file .pak của Võ Lâm Truyền Kỳ (định dạng XPackFile của engine gốc) — lấy file con ra theo đường dẫn.

    python tools/vltk_pak.py <thư mục client> <đường dẫn trong pak> [...] -o <thư mục output>
    VD: python tools/vltk_pak.py D:/.../Client_VLTK spr/npcres/man/ma_bd_001_st01.spr -o out

Theo đúng mã nguồn Engine/Src/XPackFile.cpp + KPakList.cpp:
  Header 32 byte: "PACK", uCount, uIndexTableOffset, uDataOffset, uCrc32, 12 byte dự trữ
  Bảng index uCount x 16 byte: uId, uOffset, lSize (kích thước gốc), lCompressSizeFlag
      (byte cao = cách nén: 0 không nén, 0x01/0x20 UCL nrv2b, 0x10 = SPR nén TỪNG FRAME; 3 byte thấp = cỡ nén)
  uId = băm đường dẫn "\\spr\\npcres\\..." viết thường (KPakList::FileNameToId).
SPR nén từng frame: [SPRHEAD 32][bảng màu][Frames x (lCompressSize, lSize)][dữ liệu frame] — lSize < 0 nghĩa là
frame không nén (cỡ -lSize). Hàm read() dựng lại thành file SPR thường (bảng offset + frame) để spr_to_png.py đọc.

Thứ tự tìm: file rời trên đĩa trước, rồi các pak theo thứ tự trong package.ini của client (giống game gốc).
"""
import os
import struct
import sys

TYPE_NONE = 0x00
TYPE_UCL = 0x01
TYPE_UPL_NEW = 0x20
TYPE_FRAME = 0x10


def file_name_to_id(path):
    """KPakList::FileNameToId — path dạng "\\spr\\npcres\\man\\x.spr"."""
    uid = 0
    for index, ch in enumerate(path.encode("gbk"), 1):
        if 65 <= ch <= 90:
            ch += 32
        if ch >= 128:  ## char có dấu trong C
            ch -= 256
        uid = ((uid + index * ch) % 0x8000000B * 0xFFFFFFEF) & 0xFFFFFFFF
    return uid ^ 0x12345678


def normalize(path):
    path = path.replace("/", "\\").lower()
    return path if path.startswith("\\") else "\\" + path


def ucl_nrv2b_decompress(src, dst_len):
    """ucl_nrv2b_decompress_8 (thư viện UCL) — viết lại bằng Python."""
    dst = bytearray()
    ilen = 0
    bb = 0

    def getbit():
        nonlocal bb, ilen
        if bb & 0x7F:
            bb *= 2
        else:
            bb = src[ilen] * 2 + 1
            ilen += 1
        return (bb >> 8) & 1

    last_m_off = 1
    while True:
        while getbit():
            dst.append(src[ilen])
            ilen += 1
        m_off = 1
        while True:
            m_off = m_off * 2 + getbit()
            if getbit():
                break
        if m_off == 2:
            m_off = last_m_off
        else:
            m_off = (m_off - 3) * 256 + src[ilen]
            ilen += 1
            if m_off == 0xFFFFFFFF:
                break
            m_off += 1
            last_m_off = m_off
        m_len = getbit()
        m_len = m_len * 2 + getbit()
        if m_len == 0:
            m_len = 1
            while True:
                m_len = m_len * 2 + getbit()
                if getbit():
                    break
            m_len += 2
        m_len += 1 if m_off > 0xD00 else 0
        pos = len(dst) - m_off
        for k in range(m_len + 1):
            dst.append(dst[pos + k])
    if len(dst) != dst_len:
        raise ValueError("UCL: giải nén ra %d byte, mong đợi %d" % (len(dst), dst_len))
    return bytes(dst)


class PakFile:
    def __init__(self, path):
        self.path = path
        self.f = open(path, "rb")
        sig, count, index_offset, _data_offset, _crc = struct.unpack("<4sIIII", self.f.read(20))
        if sig != b"PACK":
            raise ValueError("không phải pak: " + path)
        self.f.seek(index_offset)
        raw = self.f.read(count * 16)
        self.index = {}
        for i in range(count):
            uid, offset, size, flag = struct.unpack_from("<IIiI", raw, i * 16)
            self.index[uid] = (offset, size, flag)

    def _extract(self, method, offset, comp_size, size):
        self.f.seek(offset)
        data = self.f.read(comp_size)
        if method == TYPE_NONE:
            return data[:size]
        if method in (TYPE_UCL, TYPE_UPL_NEW):
            return ucl_nrv2b_decompress(data, size)
        raise ValueError("cách nén chưa hỗ trợ: 0x%02x" % method)

    def read(self, uid):
        offset, size, flag = self.index[uid]
        method = flag >> 24
        comp_size = flag & 0xFFFFFF
        if not method & TYPE_FRAME:
            return self._extract(method, offset, comp_size, size)
        ## SPR nén từng frame -> dựng lại SPR thường.
        method &= 0x0F
        self.f.seek(offset)
        header = self.f.read(32)
        frames, colors = struct.unpack_from("<HH", header, 12)
        palette = self.f.read(colors * 3)
        infos = [struct.unpack("<ii", self.f.read(8)) for _ in range(frames)]
        pos = offset + 32 + colors * 3 + frames * 8
        frame_data = []
        for frame_comp, frame_size in infos:
            if frame_size < 0:
                self.f.seek(pos)
                frame_data.append(self.f.read(-frame_size))
            else:
                frame_data.append(self._extract(method, pos, frame_comp, frame_size))
            pos += frame_comp
        table = bytearray()
        cursor = 0
        for d in frame_data:
            table += struct.pack("<II", cursor, len(d))
            cursor += len(d)
        return header + palette + bytes(table) + b"".join(frame_data)


class PakList:
    """Toàn bộ pak của 1 client, tìm theo thứ tự package.ini; file rời trên đĩa được ưu tiên."""

    def __init__(self, client_dir):
        self.client_dir = client_dir
        self.paks = []
        ini = os.path.join(client_dir, "package.ini")
        names = []
        for line in open(ini, encoding="latin1"):
            key, _, value = line.strip().partition("=")
            if key.isdigit():
                names.append((int(key), value))
        for _, name in sorted(names):
            p = os.path.join(client_dir, "data", name)
            if os.path.isfile(p):
                self.paks.append(PakFile(p))

    def read(self, path):
        loose = os.path.join(self.client_dir, normalize(path).lstrip("\\").replace("\\", os.sep))
        if os.path.isfile(loose):
            return open(loose, "rb").read()
        uid = file_name_to_id(normalize(path))
        for pak in self.paks:
            if uid in pak.index:
                return pak.read(uid)
        return None


def main():
    args = sys.argv[1:]
    if "-o" not in args or len(args) < 4:
        print(__doc__)
        sys.exit(1)
    out = args[args.index("-o") + 1]
    client, paths = args[0], [a for a in args[1:args.index("-o")]]
    paks = PakList(client)
    for p in paths:
        data = paks.read(p)
        if data is None:
            print("KHÔNG THẤY:", p)
            continue
        dest = os.path.join(out, normalize(p).lstrip("\\").replace("\\", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, "wb").write(data)
        print("OK", p, len(data))


if __name__ == "__main__":
    main()
