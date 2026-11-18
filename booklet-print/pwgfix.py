# pwgfix.py FILE.pwg : fill in the header fields CUPS leaves empty (total page count, print quality,
# PWG media names) in every page header of a PWG raster file, in place.
import sys, struct
p = sys.argv[1]; d = bytearray(open(p, 'rb').read()); assert d[:4] == b'RaS2'
offs = []; pos = 4
while pos < len(d):
    offs.append(pos); h = d[pos:pos+1796]
    w, hgt, bpp = (struct.unpack('>I', h[o:o+4])[0] for o in (372, 376, 388)); B = bpp // 8
    pos += 1796; line = 0
    while line < hgt:
        line += d[pos] + 1; pos += 1; x = 0
        while x < w:
            c = d[pos]; pos += 1
            if c < 0x80: pos += B; x += c + 1
            else: pos += (257 - c) * B; x += 257 - c
def put_s(o, off, s): d[o+off:o+off+64] = s.encode().ljust(64, b'\0')
for o in offs:
    d[o+452:o+456] = struct.pack('>I', len(offs))      # TotalPageCount
    d[o+484:o+488] = struct.pack('>I', 4)              # PrintQuality = normal
    put_s(o, 128, 'stationery')                        # MediaType
    put_s(o, 1732, 'iso_a4_210x297mm')                 # PageSizeName
open(p, 'wb').write(d); print(p, 'pages:', len(offs))
