#!/usr/bin/env python3
"""Rasterize Hyner's own geometric monogram using only the Python standard library."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]


def rounded(x, y, left, top, width, height, radius):
    dx = max(left + radius - x, 0, x - (left + width - radius))
    dy = max(top + radius - y, 0, y - (top + height - radius))
    return left <= x <= left + width and top <= y <= top + height and dx * dx + dy * dy <= radius * radius


def pixel(x, y):
    if not rounded(x, y, 0, 0, 1, 1, .25):
        return (0, 0, 0, 0)
    white = rounded(x, y, .25, .23, .15, .54, .035) or rounded(x, y, .60, .23, .15, .54, .035)
    white = white or (.35 <= x <= .65 and .49 - (x - .35) * 14 / 30 <= y <= .66 - (x - .35) * 14 / 30)
    return (255, 255, 255, 255) if white else (105, 82, 217, 255)


def render(size, destination):
    rows = bytearray()
    samples = 3
    for y in range(size):
        rows.append(0)
        for x in range(size):
            values = [pixel((x + (sx + .5) / samples) / size, (y + (sy + .5) / samples) / size) for sy in range(samples) for sx in range(samples)]
            rows.extend(round(sum(v[channel] for v in values) / len(values)) for channel in range(4))

    def chunk(kind, content):
        return struct.pack('!I', len(content)) + kind + content + struct.pack('!I', zlib.crc32(kind + content) & 0xffffffff)

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


if __name__ == '__main__':
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        render(size, ROOT / 'android/app/src/main/res' / f'mipmap-{density}' / 'ic_launcher.png')
    render(512, ROOT / 'assets/branding/hyner-icon.png')
    print('Hyner launcher icons generated.')
