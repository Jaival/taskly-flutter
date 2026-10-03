"""Draws Taskly's app icon: a white check mark on the brand purple.

Run from the repo root, then `dart run flutter_launcher_icons` to size it
for every platform:

    python tool/make_icons.py
"""

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # Draw large, then shrink, for smooth edges.
PURPLE = (0x54, 0x45, 0x8D, 255)
WHITE = (255, 255, 255, 255)


def check(draw, size, stroke, points):
    """A check mark with rounded ends and a rounded corner."""
    pts = [(x * size, y * size) for x, y in points]
    draw.line(pts, fill=WHITE, width=stroke, joint="curve")
    r = stroke / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)


def icon(background, scale_of_mark):
    big = SIZE * SCALE
    image = Image.new("RGBA", (big, big), background)
    draw = ImageDraw.Draw(image)
    # The mark's shape in a unit square, then shrunk towards the centre.
    shape = [(0.22, 0.53), (0.42, 0.72), (0.78, 0.33)]
    s = scale_of_mark
    points = [(0.5 + (x - 0.5) * s, 0.5 + (y - 0.5) * s) for x, y in shape]
    check(draw, big, int(big * 0.11 * s), points)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


# Full-bleed, with the mark inside the maskable safe zone (a centred circle
# 80% wide), so one image works for every platform and for PWA masks.
icon(PURPLE, 0.85).save("assets/icon/icon.png")
# Android adaptive and themed icons: the mark alone. The launcher adds the
# background and crops to its own shape.
icon((0, 0, 0, 0), 1.0).save("assets/icon/foreground.png")
