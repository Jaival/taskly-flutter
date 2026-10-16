"""Draws Taskly's app icon: a short to-do list on the brand violet. Three
rows, each a box and a line, the first box ticked, the rows fading as they
go down.

Run from the repo root, then `dart run flutter_launcher_icons` to size it
for every platform:

    python tool/make_icons.py

The app draws the same mark itself (`TasklyLogo`), so keep the two in step.
"""

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # Draw large, then shrink, for smooth edges.
VIOLET = (0x61, 0x48, 0xD1, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

# The mark on a 100-unit square, as in the logo's SVG. Each row is
# (box, line, opacity); the first box is filled and ticked, the others are
# outlines.
ROWS = [
    ((22, 25, 15, 15), (44, 29, 34, 7), 1.0),
    ((23.5, 44.5, 12, 12), (44, 47, 28, 7), 0.75),
    ((23.5, 62.5, 12, 12), (44, 65, 22, 7), 0.5),
]
TICK = [(25.5, 32.5), (28.5, 35.5), (34, 29.5)]
# The mark spans y 25 to 72: move it down a little to centre it.
NUDGE = 1.5


def mark(scale_of_mark):
    """The mark alone, white on transparent, the tick cut out of its box."""
    big = SIZE * SCALE
    unit = big / 100

    def at(x, y):
        s = scale_of_mark
        return ((50 + (x - 50) * s) * unit, (50 + (y + NUDGE - 50) * s) * unit)

    def length(n):
        return n * scale_of_mark * unit

    image = Image.new("RGBA", (big, big), CLEAR)
    for i, ((bx, by, bw, bh), (lx, ly, lw, lh), opacity) in enumerate(ROWS):
        row = Image.new("RGBA", (big, big), CLEAR)
        draw = ImageDraw.Draw(row)
        box = (*at(bx, by), *at(bx + bw, by + bh))
        if i == 0:
            draw.rounded_rectangle(box, radius=length(4), fill=WHITE)
            # Cut the tick out, so the background shows through it.
            points = [at(x, y) for x, y in TICK]
            stroke = int(length(3))
            draw.line(points, fill=CLEAR, width=stroke, joint="curve")
            r = stroke / 2
            for x, y in (points[0], points[-1]):
                draw.ellipse((x - r, y - r, x + r, y + r), fill=CLEAR)
        else:
            # An outline 3 wide, centred on the box's edge.
            half = length(1.5)
            draw.rounded_rectangle(
                (box[0] - half, box[1] - half, box[2] + half, box[3] + half),
                radius=length(3) + half,
                outline=WHITE,
                width=int(length(3)),
            )
        line = (*at(lx, ly), *at(lx + lw, ly + lh))
        draw.rounded_rectangle(line, radius=length(lh / 2), fill=WHITE)
        if opacity < 1:
            alpha = row.getchannel("A").point(lambda a: int(a * opacity))
            row.putalpha(alpha)
        image = Image.alpha_composite(image, row)
    return image


def icon(background, scale_of_mark):
    big = SIZE * SCALE
    image = Image.new("RGBA", (big, big), background)
    image = Image.alpha_composite(image, mark(scale_of_mark))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


# Full-bleed, with the mark inside the maskable safe zone (a centred circle
# 80% wide), so one image works for every platform and for PWA masks.
icon(VIOLET, 1.0).save("assets/icon/icon.png")
# Android adaptive and themed icons: the mark alone, smaller, since the
# launcher shows only the middle two thirds. It adds the background and
# crops to its own shape.
icon(CLEAR, 0.8).save("assets/icon/foreground.png")
