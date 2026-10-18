"""Reject corrupt/truncated brand PNGs before Xcode can compile a partial image."""
from pathlib import Path
import struct
import zlib
import hashlib

path = Path("WdCar/Resources/Assets.xcassets/LogoDay.imageset/logo_day.png")
data = path.read_bytes()
assert data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG signature"
offset, compressed, ended = 8, bytearray(), False
width = height = 0
while offset < len(data):
    length = struct.unpack(">I", data[offset:offset + 4])[0]
    kind = data[offset + 4:offset + 8]
    payload = data[offset + 8:offset + 8 + length]
    stored = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
    assert zlib.crc32(kind + payload) & 0xffffffff == stored, f"Corrupt PNG chunk: {kind}"
    if kind == b"IHDR":
        width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", payload)
        assert (width, height, depth, color, interlace) == (1145, 1373, 8, 6, 0)
    if kind == b"IDAT": compressed.extend(payload)
    offset += length + 12
    if kind == b"IEND": ended = True; break
assert ended, "PNG has no IEND"
assert len(zlib.decompress(compressed)) == height * (width * 4 + 1), "Incomplete PNG scanlines"
print(f"OK: LogoDay complete {width}x{height}; SHA256 {hashlib.sha256(data).hexdigest()}")
