"""Draws the demo account's profile photos into assets/avatars/.

The demo backend has no server to download anything from, so without these
every avatar in the app falls back to its monogram and the photo path is
never exercised at all — which reads as a bug rather than as a demo.

They are abstract on purpose: soft out-of-focus shapes over a gradient, no
likeness of anybody, nothing licensed. Run this again to regenerate them;
nothing else reads it, and the PNGs it writes are committed.

    python3 tool/make_demo_avatars.py
"""

import math
import os
import struct
import zlib

SIZE = 128
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'avatars')

# (name, background pair, blob colours). Chosen to sit apart from each other in
# a chat list, and to stay legible behind the white ring the avatar draws.
PALETTES = [
    ('01', ((14, 62, 122), (86, 176, 214)), [(240, 214, 130), (255, 255, 255)]),
    ('02', ((92, 26, 82), (222, 108, 132)), [(255, 196, 150), (120, 40, 110)]),
    ('03', ((16, 84, 66), (128, 196, 120)), [(238, 236, 160), (24, 60, 52)]),
    ('04', ((104, 44, 16), (226, 148, 72)), [(252, 220, 170), (86, 34, 20)]),
    ('05', ((32, 36, 96), (118, 126, 208)), [(196, 206, 255), (28, 28, 64)]),
    ('06', ((122, 40, 40), (226, 126, 96)), [(250, 206, 168), (90, 26, 34)]),
    ('07', ((24, 76, 96), (96, 178, 190)), [(214, 240, 236), (18, 52, 70)]),
]


def blobs_for(index):
    """Deterministic blob layout — same seed, same picture, every run."""
    out = []
    for i in range(4):
        angle = (index * 1.7 + i * 2.3) % (2 * math.pi)
        radius = SIZE * (0.18 + 0.10 * ((index + i) % 3))
        cx = SIZE * 0.5 + math.cos(angle) * SIZE * 0.26
        cy = SIZE * 0.5 + math.sin(angle) * SIZE * 0.24
        out.append((cx, cy, radius, i % 2))
    return out


def render(palette_index):
    _, (top, bottom), blob_colours = PALETTES[palette_index]
    blobs = blobs_for(palette_index)
    rows = []

    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            # Diagonal gradient underneath everything.
            t = (x + y) / (2 * (SIZE - 1))
            pixel = [top[c] + (bottom[c] - top[c]) * t for c in range(3)]

            # Soft shapes on top. The falloff is smoothstep over the blob
            # radius, which is what makes them read as out of focus.
            for cx, cy, radius, which in blobs:
                d = math.hypot(x - cx, y - cy) / radius
                if d >= 1.0:
                    continue
                k = 1.0 - d
                alpha = k * k * (3 - 2 * k) * 0.55
                colour = blob_colours[which]
                pixel = [
                    pixel[c] + (colour[c] - pixel[c]) * alpha for c in range(3)
                ]

            row += bytes(max(0, min(255, int(round(v)))) for v in pixel)
        rows.append(row)

    # PNG wants a filter byte per scanline; 0 means "store as is".
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    return raw


def chunk(tag, payload):
    return (
        struct.pack('>I', len(payload))
        + tag
        + payload
        + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_png(path, raw):
    header = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0)
    data = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', header)
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )
    with open(path, 'wb') as handle:
        handle.write(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    for index, (name, _, _) in enumerate(PALETTES):
        path = os.path.join(OUT, f'demo-{name}.png')
        write_png(path, render(index))
        print(f'{path}  {os.path.getsize(path)} bytes')


if __name__ == '__main__':
    main()
