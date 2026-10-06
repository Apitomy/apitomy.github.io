#!/usr/bin/env python3
"""Regenerate the brand images (og card, logo, favicons) into assets/images/.

Colors are read from _sass/_variables.scss so the images track the site
palette. Requires Pillow; runs fully offline.
"""

import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "assets", "images")
SASS = os.path.join(REPO, "_sass")

BOLD_FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REGULAR_FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"

SS = 4  # tile supersampling factor, downscaled with LANCZOS for crisp edges


def read_sass(name):
    with open(os.path.join(SASS, name)) as handle:
        return handle.read()


VARIABLES = read_sass("_variables.scss")


def sass_variable(name):
    match = re.search(r"\$" + name + r":\s*(#[0-9A-Fa-f]{6})\s*;", VARIABLES)
    if not match:
        sys.exit("missing $" + name + " in _sass/_variables.scss")
    return match.group(1)


NAVY = sass_variable("color-bg-dark")
ACCENT = sass_variable("color-accent")
ACCENT_DARK = sass_variable("color-accent-dark")
SLATE = sass_variable("color-text-light")
HERO_TEXT = sass_variable("color-text-on-dark")


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def rgba(hex_color, alpha):
    return rgb(hex_color) + (alpha,)


def save(image, name, **save_kwargs):
    path = os.path.join(OUT_DIR, name)
    image.save(path, **save_kwargs)
    with Image.open(path) as written:
        print(f"{os.path.abspath(path)} {written.size[0]}x{written.size[1]}")


def write_og_card():
    img = Image.new("RGB", (1200, 630), NAVY).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.polygon([(985, 0), (1200, 0), (1200, 170), (1085, 330)], fill=rgba(ACCENT, 96))
    draw.polygon([(1090, 0), (1200, 0), (1200, 60), (1150, 170)], fill=rgba(ACCENT, 45))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)
    draw.text((80, 260), "Apitomy", font=ImageFont.truetype(BOLD_FONT, 110),
              fill="#FFFFFF", anchor="ls")
    draw.text((80, 352), "Open source tools for OpenAPI and AsyncAPI",
              font=ImageFont.truetype(REGULAR_FONT, 42), fill=HERO_TEXT, anchor="ls")
    draw.text((80, 550), "apitomy.io", font=ImageFont.truetype(REGULAR_FONT, 28),
              fill=SLATE, anchor="ls")
    save(img.convert("RGB"), "og-default.png")


def draw_tile(px, rounded):
    tile = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    top, bottom = rgb(ACCENT), rgb(ACCENT_DARK)
    gradient = Image.new("RGB", (1, px))
    for y in range(px):
        t = y / (px - 1)
        gradient.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    gradient = gradient.resize((px, px))
    if rounded:
        mask = Image.new("L", (px, px), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, px - 1, px - 1],
                                               radius=int(px * 0.225), fill=255)
        tile.paste(gradient, (0, 0), mask)
    else:
        tile.paste(gradient, (0, 0))
    draw = ImageDraw.Draw(tile)
    font = ImageFont.truetype(BOLD_FONT, int(px * 300 / 512))
    bbox = draw.textbbox((0, 0), "A", font=font)
    x = (px - (bbox[2] - bbox[0])) / 2 - bbox[0]
    y = (px - (bbox[3] - bbox[1])) / 2 - bbox[1]
    draw.text((x, y), "A", font=font, fill="#FFFFFF")
    return tile


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_og_card()

    tile = draw_tile(512 * SS, rounded=True)
    save(tile.resize((512, 512), Image.LANCZOS), "logo.png")
    favicon_32 = tile.resize((32, 32), Image.LANCZOS)
    favicon_16 = tile.resize((16, 16), Image.LANCZOS)
    save(favicon_32, "favicon-32.png")
    save(favicon_16, "favicon-16.png")

    # iOS applies its own corner mask, so the touch icon ships as an opaque square.
    touch = draw_tile(180 * SS, rounded=False).resize((180, 180), Image.LANCZOS)
    save(touch.convert("RGB"), "apple-touch-icon.png")

    save(favicon_32, "favicon.ico", format="ICO", sizes=[(16, 16), (32, 32)])


if __name__ == "__main__":
    main()
