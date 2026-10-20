#!/usr/bin/env python3
"""Minimal PPM (P6/P5) -> PNG converter, no third-party deps."""
import struct, sys, zlib

def read_ppm(path):
    data = open(path, "rb").read()
    # split header: magic, width, height, maxval
    vals, i = [], 0
    while len(vals) < 4:
        # skip whitespace/comments
        while i < len(data) and data[i : i + 1].isspace():
            i += 1
        if data[i : i + 1] == b"#":
            while i < len(data) and data[i : i + 1] != b"\n":
                i += 1
            continue
        j = i
        while j < len(data) and not data[j : j + 1].isspace():
            j += 1
        vals.append(data[i:j])
        i = j
    i += 1  # single whitespace after maxval
    magic, w, h, maxv = vals[0], int(vals[1]), int(vals[2]), int(vals[3])
    if magic != b"P6":
        raise SystemExit("only P6 supported, got %r" % magic)
    return w, h, data[i : i + w * h * 3]

def write_png(path, w, h, rgb):
    raw = b"".join(b"\x00" + rgb[y * w * 3 : (y + 1) * w * 3] for y in range(h))
    def chunk(tag, payload):
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)
    print("wrote %s (%dx%d)" % (path, w, h))

if __name__ == "__main__":
    write_png(sys.argv[2], *read_ppm(sys.argv[1]))
