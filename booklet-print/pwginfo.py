import sys, struct
def parse(path):
    d = open(path, 'rb').read()
    print(f'{path}: sync={d[:4]!r} size={len(d)}')
    pos = 4; n = 0
    while pos < len(d):
        h = d[pos:pos+1796]; pos += 1796; n += 1
        u = lambda off: struct.unpack('>I', h[off:off+4])[0]
        s = lambda off: h[off:off+64].split(b'\0')[0].decode('latin1')
        i = lambda k: struct.unpack('>i', h[452+4*k:456+4*k])[0]
        w, hgt, bpp, bpl = u(372), u(376), u(388), u(392)
        B = bpp // 8; line = 0; inked = 0
        while line < hgt:
            rep = d[pos] + 1; pos += 1; x = 0; white = True
            while x < w:
                c = d[pos]; pos += 1
                if c < 0x80:
                    if d[pos:pos+B] != b'\xff' * B: white = False
                    pos += B; x += c + 1
                else:
                    cnt = 257 - c; chunk = d[pos:pos+cnt*B]
                    if chunk.count(b'\xff') != len(chunk): white = False
                    pos += cnt * B; x += cnt
            if not white: inked += rep
            line += rep
        print(f'  page {n}: class={s(0)!r} type={s(128)!r} {w}x{hgt} res={u(276)}x{u(280)} bpp={bpp} cs={u(400)} Duplex={u(272)} Tumble={u(368)} MediaPos={u(324)} '
              f'TotalPageCount={i(0)} CrossFeed={i(1)} Feed={i(2)} PrintQuality={i(8)} sizeName={s(1732)!r} inked lines={inked}')
    print('  pages parsed:', n)
for p in sys.argv[1:]: parse(p)
