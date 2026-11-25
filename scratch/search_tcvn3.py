# TCVN3 to Unicode mapping table
TCVN3_MAP = {
    0x80: '\u00e0',  # à
    0x81: '\u1ea3',  # ả
    0x82: '\u00e3',  # ã
    0x83: '\u00e1',  # á
    0x84: '\u1ea1',  # ạ
    0x85: '\u1ea7',  # ầ
    0x86: '\u1ea9',  # ẩ
    0x87: '\u1eab',  # ẫ
    0x88: '\u1ea5',  # ấn
    0x89: '\u1ead',  # ậ
    0x8a: '\u1eb3',  # ẳ
    0x8b: '\u1eb5',  # ẵ
    0x8c: '\u1eaf',  # ắ
    0x8d: '\u1eb7',  # ặ
    0x8e: '\u00e8',  # è
    0x8f: '\u1ebb',  # ẻ
    0x90: '\u1ebd',  # ẽ
    0x91: '\u00e9',  # é
    0x92: '\u1eb9',  # ẹ
    0x93: '\u1ec1',  # ề
    0x94: '\u1ec3',  # ể
    0x95: '\u1ec5',  # ễ
    0x96: '\u1ebf',  # ế
    0x97: '\u1ec7',  # ệ
    0x98: '\u00ec',  # ì
    0x99: '\u1ec9',  # ỉ
    0x9a: '\u0129',  # ĩ
    0x9b: '\u00ed',  # í
    0x9c: '\u1ecb',  # ị
    0x9d: '\u00f2',  # ò
    0x9e: '\u1ecf',  # ỏ
    0x9f: '\u00f5',  # õ
    0xa1: '\u0103',  # ă
    0xa2: '\u00e2',  # â
    0xa3: '\u0111',  # đ
    0xa4: '\u00ea',  # ê
    0xa5: '\u00f4',  # ô
    0xa6: '\u01a1',  # ơ
    0xa7: '\u01b0',  # ư
    0xa8: '\u0102',  # Ă
    0xa9: '\u00c2',  # Â
    0xaa: '\u0110',  # Đ
    0xab: '\u00ca',  # Ê
    0xac: '\u00d4',  # Ô
    0xad: '\u01a0',  # Ơ or ư? Let's check
    0xb5: '\u00e0',
    0xb6: '\u1ea3',
    0xb7: '\u00e3',
    0xb8: '\u00e1',
    0xb9: '\u1ea1',
    0xbb: '\u1ec1',
    0xbc: '\u1ec3',
    0xbd: '\u1ec5',
    0xbe: '\u1ebf',
    0xbf: '\u1ec7',
    0xc0: '\u00f2',
    0xc1: '\u1ecf',
    0xc2: '\u00f5',
    0xc3: '\u00f3',
    0xc4: '\u1ecd',
    0xc5: '\u1ed3',
    0xc6: '\u1ed5',
    0xc7: '\u1ed7',
    0xc8: '\u1ed1',
    0xc9: '\u1ed9',
    0xca: '\u1edd',
    0xcb: '\u1edf',
    0xcc: '\u1ee1',
    0xcd: '\u1edb',
    0xce: '\u1ee3',
    0xcf: '\u00f9',
    0xd0: '\u1ee7',
    0xd1: '\u0169',
    0xd2: '\u00fa',
    0xd3: '\u1ee5',
    0xd4: '\u1eeb',
    0xd5: '\u1eed',
    0xd6: '\u1eef',
    0xd7: '\u1ee9',
    0xd8: '\u1ef1',
    0xd9: '\u1ef3',
    0xda: '\u1ef7',
    0xdb: '\u1ef9',
    0xdc: '\u00fd',
    0xdd: '\u1ef5',
    0xde: '\u1ecb',
    0xdf: '\u00f3',
    0xe1: '\u00e1',
    0xe2: '\u00e0',
    0xe3: '\u1ea3',
    0xe4: '\u00e3',
    0xe5: '\u1ea1',
    0xe6: '\u1ea5',
    0xe7: '\u1ea7',
    0xe8: '\u1ed1', # ố
    0xe9: '\u1eab',
    0xea: '\u1ead',
    0xeb: '\u1eaf',
    0xec: '\u1eb1',
    0xed: '\u1eb3',
    0xee: '\u1eb5',
    0xef: '\u1eb7',
    0xf1: '\u00e9',
    0xf2: '\u00e8',
    0xf3: '\u1ebb',
    0xf4: '\u1ebd',
    0xf5: '\u1eb9',
    0xf6: '\u1eed', # ử
    0xf7: '\u1ec1',
    0xf8: '\u1ec3',
    0xf9: '\u1ec5',
    0xfa: '\u1ec7',
    0xfb: '\u00ed',
    0xfc: '\u00ec',
    0xfd: '\u1ec9',
    0xfe: '\u0129',
}

def tcvn3_to_unicode(b: bytes) -> str:
    res = []
    for byte in b:
        if byte in TCVN3_MAP:
            res.append(TCVN3_MAP[byte])
        elif byte < 128:
            res.append(chr(byte))
        else:
            res.append(f"\\x{byte:02x}")
    return "".join(res)

import os
skill_files = [
    r'D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\settings\Skills.txt',
    r'D:\game\source_vo-lam-truyen-ky\VS2022\Server+Client-001\bin\client\settings\Skills.txt'
]

for sf in skill_files:
    if not os.path.exists(sf): continue
    print("=== Search in:", sf)
    with open(sf, 'rb') as f:
        header = f.readline().split(b'\t')
        for i, line in enumerate(f, 2):
            cols = line.strip().split(b'\t')
            if len(cols) < 3: continue
            name_raw = cols[0]
            name_u = tcvn3_to_unicode(name_raw)
            sid = cols[2].decode('ascii', errors='ignore')
            # search for that tiet / chan vo / chan vu / wudang skills
            if any(k in name_u.lower() for k in ['th\u1ea5t', 'ti\u1ebft', 'ch\u00e2n v', 'v\u00f5 \u0111ang', 'v\u0169']):
                print(f"Line {i}: ID={sid} | RawName={name_u}")
            # Also check if SkillDesc has anything
            if len(cols) > 113:
                desc_u = tcvn3_to_unicode(cols[113])
                if any(k in desc_u.lower() for k in ['th\u1ea5t ti\u1ebft', 'ch\u00e2n v\u00f5', 'ch\u00e2n v\u0169']):
                    print(f"Found in desc line {i}: ID={sid} | Name={name_u}")
