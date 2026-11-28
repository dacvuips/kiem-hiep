def ucl_nrv2b_fast(src, dst_len):
    dst = bytearray(dst_len)
    ilen = 0
    olen = 0
    bb = 0
    
    src_len = len(src)
    last_m_off = 1
    
    while olen < dst_len:
        # getbit inline
        if bb & 0x7F:
            bb *= 2
        else:
            bb = src[ilen] * 2 + 1
            ilen += 1
        b = (bb >> 8) & 1
        
        while b:
            dst[olen] = src[ilen]
            olen += 1
            ilen += 1
            if olen >= dst_len:
                break
            if bb & 0x7F:
                bb *= 2
            else:
                bb = src[ilen] * 2 + 1
                ilen += 1
            b = (bb >> 8) & 1
            
        if olen >= dst_len:
            break
            
        m_off = 1
        while True:
            if bb & 0x7F:
                bb *= 2
            else:
                bb = src[ilen] * 2 + 1
                ilen += 1
            m_off = m_off * 2 + ((bb >> 8) & 1)
            
            if bb & 0x7F:
                bb *= 2
            else:
                bb = src[ilen] * 2 + 1
                ilen += 1
            if (bb >> 8) & 1:
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
            
        if bb & 0x7F:
            bb *= 2
        else:
            bb = src[ilen] * 2 + 1
            ilen += 1
        m_len = (bb >> 8) & 1
        
        if bb & 0x7F:
            bb *= 2
        else:
            bb = src[ilen] * 2 + 1
            ilen += 1
        m_len = m_len * 2 + ((bb >> 8) & 1)
        
        if m_len == 0:
            m_len = 1
            while True:
                if bb & 0x7F:
                    bb *= 2
                else:
                    bb = src[ilen] * 2 + 1
                    ilen += 1
                m_len = m_len * 2 + ((bb >> 8) & 1)
                
                if bb & 0x7F:
                    bb *= 2
                else:
                    bb = src[ilen] * 2 + 1
                    ilen += 1
                if (bb >> 8) & 1:
                    break
            m_len += 2
            
        m_len += 1 if m_off > 0xD00 else 0
        pos = olen - m_off
        for k in range(m_len + 1):
            dst[olen] = dst[pos + k]
            olen += 1
            
    return bytes(dst)

# Test with a sample from skills.pak
import sys
sys.path.insert(0, 'tools')
from vltk_pak import PakFile
pak = PakFile(r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data\skills.pak')
import time
t0 = time.time()
for uid, (off, sz, fl) in list(pak.index.items())[:20]:
    if ((fl >> 24) & 0xFF) == 1 and sz < 200000:
        pak.f.seek(off)
        comp = pak.f.read(fl & 0x00FFFFFF)
        data = ucl_nrv2b_fast(comp, sz)
print(f"Decompressed 20 files in {time.time() - t0:.2f}s!")
