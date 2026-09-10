"""Render the iOS LaunchImage set from the alpha-extracted mark.

The storyboard declares the image at 160x140 pt and uses contentMode="center",
so each scale renders at its intrinsic point size with no resampling. These
dimensions must match the mark width the Dart splash draws (SplashGate's
_kMarkWidth), or the native-to-Flutter handoff will visibly jump.

Run after tool/icon/extract_mark.py:
    /opt/homebrew/bin/python3 tool/icon/extract_mark.py
    /opt/homebrew/bin/python3 tool/icon/make_launch_images.py
"""

from PIL import Image

SRC = 'assets/icon/momera_recording_logo.png'
DEST = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
PT_W = 160
CHROMA_REF, CHROMA_FLOOR = 145.0, 3.0
BG = (253.0, 253.0, 253.0)

src = Image.open(SRC).convert('RGB')
w, h = src.size
out = Image.new('RGBA', (w, h))
sp, op = src.load(), out.load()
for y in range(h):
    for x in range(w):
        r, g, b = sp[x, y]
        a = min(1.0, max(0.0, ((max(r, g, b) - min(r, g, b)) - CHROMA_FLOOR) / CHROMA_REF))
        if a <= 0.0:
            op[x, y] = (0, 0, 0, 0)
            continue
        op[x, y] = (*[int(min(255, max(0, round((p - (1 - a) * bg) / a))))
                      for p, bg in zip((r, g, b), BG)], int(round(a * 255)))

mark = out.crop(out.getbbox())
pt_h = round(PT_W * mark.height / mark.width)
print(f'mark {mark.width}x{mark.height} -> {PT_W}x{pt_h} pt')

for scale in (1, 2, 3):
    suffix = '' if scale == 1 else f'@{scale}x'
    img = mark.resize((PT_W * scale, pt_h * scale), Image.LANCZOS)
    img.save(f'{DEST}/LaunchImage{suffix}.png')
    print(f'LaunchImage{suffix}.png: {img.size}')
