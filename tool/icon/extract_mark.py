"""Knock the near-white ground out of the logo and emit the icon source assets.

The source art has no alpha and a uniform #FDFDFD ground, but an adaptive-icon
foreground and a launch image both need transparency. The separation works on
chroma rather than luminance: the ground is achromatic (max-min ~2) while every
pixel of the mark is strongly chromatic (~150-197), so chroma doubles as a
coverage estimate that gets anti-aliased edges right for free. Each edge pixel
is then un-composited against white so no pale fringe survives the alpha.
"""

from PIL import Image

SRC = 'assets/icon/momera_recording_logo.png'
CHROMA_REF = 145.0   # lowest chroma observed on the mark
CHROMA_FLOOR = 3.0   # highest chroma observed on the ground
BG = (253.0, 253.0, 253.0)
MARK_FRAC = 0.5641   # mark width as a fraction of the icon canvas

src = Image.open(SRC).convert('RGB')
w, h = src.size
out = Image.new('RGBA', (w, h))
sp, op = src.load(), out.load()

for y in range(h):
    for x in range(w):
        r, g, b = sp[x, y]
        chroma = max(r, g, b) - min(r, g, b)
        a = min(1.0, max(0.0, (chroma - CHROMA_FLOOR) / CHROMA_REF))
        if a <= 0.0:
            op[x, y] = (0, 0, 0, 0)
            continue
        c = tuple(int(min(255, max(0, round((p - (1 - a) * bg) / a))))
                  for p, bg in zip((r, g, b), BG))
        op[x, y] = (*c, int(round(a * 255)))

bbox = out.getbbox()
mark = out.crop(bbox)
print(f'source {w}x{h} -> mark bbox {bbox} = {mark.width}x{mark.height}')
# The full-alpha extent. The solid (alpha>=0.5) extent measured 708x620 and is
# what the Dart painter's geometry constants normalise to; this crop is 6px
# wider because it keeps the faint anti-aliased fringe rather than clipping it.
assert (mark.width, mark.height) == (714, 626), 'mark geometry moved; re-measure'


def canvas(size, mono=False):
    tw = round(size * MARK_FRAC)
    th = round(tw * mark.height / mark.width)
    m = mark.resize((tw, th), Image.LANCZOS)
    if mono:
        # Flat white keyed by the mark's own alpha. Already grayscale, so the
        # iOS tinted variant needs no desaturation pass.
        white = Image.new('L', m.size, 255)
        m = Image.merge('RGBA', (white, white, white, m.split()[3]))
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c.paste(m, ((size - tw) // 2, (size - th) // 2), m)
    return c


for name, mono in (('mark_color_1024.png', False), ('mark_mono_1024.png', True)):
    img = canvas(1024, mono=mono)
    img.save(f'assets/icon/{name}')
    px = img.load()
    corners = [px[0, 0][3], px[1023, 0][3], px[0, 1023][3], px[1023, 1023][3]]
    assert corners == [0, 0, 0, 0], f'{name}: ground survived at the corners'
    print(f'{name}: {img.size}, corners alpha {corners}, bbox {img.getbbox()}')
