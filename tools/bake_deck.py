#!/usr/bin/env python3
"""Composite the generated deck art into finished Burns card textures.

Source art lives in assets/art/deck/source/ and is never edited in place; every
texture under assets/art/deck/ is rebuilt from it by running this script. The
frame is screen-blended over the centrepiece so the engraved border, its inner
hairline and its paper grain always sit on top of the artwork without a mask.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/art/deck/source"
OUT = ROOT / "assets/art/deck"

# Cards are 2:3; the generated frame is 9:16 and is squashed to fit.
CARD = (576, 864)
# Measured from the frame's inner hairline and title banner, as fractions.
WINDOW = (0.1222, 0.0867, 0.8750, 0.8477)
CARTOUCHE = (0.1800, 0.8563, 0.8200, 0.9125)

SUITS = ["Diamonds", "Clubs", "Hearts", "Spades"]
COURTS = {11: "Jack", 12: "Queen", 13: "King"}
TITLE_FONTS = [
    "/usr/share/fonts/opentype/urw-base35/NimbusRoman-Regular.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
]


def rect(fracs):
    x0, y0, x1, y1 = fracs
    return (round(x0 * CARD[0]), round(y0 * CARD[1]), round(x1 * CARD[0]), round(y1 * CARD[1]))


def load_gray(name):
    # Generation occasionally leaks a warm tint into props; the deck is monochrome.
    return Image.open(SOURCE / name).convert("L")


def cover(image, box):
    width, height = box[2] - box[0], box[3] - box[1]
    scale = max(width / image.width, height / image.height)
    scaled = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (scaled.width - width) // 2
    top = (scaled.height - height) // 2
    return scaled.crop((left, top, left + width, top + height))


def vignette(size, feather):
    mask = Image.new("L", size, 255)
    draw = ImageDraw.Draw(mask)
    for step in range(feather):
        shade = round(255 * step / feather)
        draw.rectangle([step, step, size[0] - 1 - step, size[1] - 1 - step], outline=shade)
    return mask


def title_font():
    # One size for the whole deck: the longest title sets it, so titles never jitter.
    box = rect(CARTOUCHE)
    width, height = box[2] - box[0], box[3] - box[1]
    longest = spaced_caps("Queen of Diamonds")
    for path in TITLE_FONTS:
        if not Path(path).exists():
            continue
        for size in range(height, 8, -1):
            font = ImageFont.truetype(path, size)
            bounds = font.getbbox(longest)
            if bounds[2] - bounds[0] <= width and bounds[3] - bounds[1] <= height * 0.72:
                return font
    return None


def spaced_caps(text):
    return " ".join(text.upper())


def draw_title(card, text, font):
    box = rect(CARTOUCHE)
    spaced = spaced_caps(text)
    if font is None:
        return
    draw = ImageDraw.Draw(card)
    bounds = draw.textbbox((0, 0), spaced, font=font)
    x = (box[0] + box[2] - (bounds[2] - bounds[0])) / 2 - bounds[0]
    y = (box[1] + box[3] - (bounds[3] - bounds[1])) / 2 - bounds[1]
    draw.text((x, y), spaced, font=font, fill=214)


def bake(art_name, title, font):
    frame = load_gray("frame.png").resize(CARD, Image.LANCZOS)
    window = rect(WINDOW)
    art = cover(load_gray(art_name), window)
    art.putalpha(vignette(art.size, 10))
    plate = Image.new("L", CARD, 0)
    plate.paste(art, window, art)
    card = ImageChops.screen(plate, frame)
    draw_title(card, title, font)
    return card


def save(image, name):
    path = OUT / name
    image.convert("RGB").save(path, "WEBP", quality=90, method=6)
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    font = title_font()
    written = []
    for suit, suit_name in enumerate(SUITS):
        # One field serves all nine number cards of a suit, so it is titled by suit.
        written.append(save(bake("field_%d.png" % suit, suit_name, font), "field_%d.webp" % suit))
        written.append(save(bake("ace_%d.png" % suit, "Ace of " + suit_name, font), "ace_%d.webp" % suit))
        for rank, court in COURTS.items():
            card = suit * 13 + rank - 1
            art = SOURCE / ("court_%d.png" % card)
            if not art.exists():
                continue  # Supplied portraits are used whole and never recomposited.
            written.append(save(bake(art.name, "%s of %s" % (court, suit_name), font), "court_%d.webp" % card))
    back = load_gray("back.png").resize(CARD, Image.LANCZOS)
    written.append(save(back, "back.webp"))
    for path in written:
        print("%8d  %s" % (path.stat().st_size, path.relative_to(ROOT)))


if __name__ == "__main__":
    main()
