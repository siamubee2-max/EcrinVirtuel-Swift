#!/usr/bin/env python3
"""YouTube thumbnail (1280x720): Lou on the left, big title on the right.
Usage: python3 scripts/lou-thumbnail.py photo.jpg out.jpg "LIGNE 1" "LIGNE 2" ["sous-titre"] [focus_y 0-1] [zoom] [focus_x 0-1]
Needs Pillow. The AI label and the brand line are always drawn."""
import sys

from PIL import Image, ImageDraw, ImageFont

W, H, PW = 1280, 720, 576
IVORY, BROWN, GOLD = (237, 230, 218), (48, 70, 107), (201, 162, 75)
F = "/usr/share/fonts/opentype/inter/"


def main():
    photo, out, l1, l2 = sys.argv[1:5]
    sub = sys.argv[5] if len(sys.argv) > 5 else ""
    fy = float(sys.argv[6]) if len(sys.argv) > 6 else 0.2
    zoom = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0
    fx = float(sys.argv[8]) if len(sys.argv) > 8 else 0.5
    img = Image.new("RGB", (W, H), IVORY)
    p = Image.open(photo).convert("RGB")
    s = max(PW / p.width, H / p.height) * zoom
    p = p.resize((round(p.width * s), round(p.height * s)), Image.LANCZOS)
    top = int((p.height - H) * fy)
    img.paste(p.crop((int((p.width - PW) * fx), top, int((p.width - PW) * fx) + PW, top + H)), (0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([PW, 0, PW + 8, H], fill=GOLD)
    x = PW + 60
    d.text((x, 90), "L'ÉCRIN VIRTUEL", font=ImageFont.truetype(F + "Inter-Bold.otf", 34), fill=GOLD)
    f1 = ImageFont.truetype(F + "Inter-Black.otf", 118)
    size = 118
    while d.textlength(max((l1, l2), key=len), font=f1) > W - x - 40:
        size -= 4
        f1 = ImageFont.truetype(F + "Inter-Black.otf", size)
    d.text((x, 190), l1, font=f1, fill=BROWN)
    d.text((x, 190 + size + 8), l2, font=f1, fill=GOLD)
    if sub:
        d.text((x, 190 + 2 * size + 50), sub, font=ImageFont.truetype(F + "Inter-SemiBold.otf", 44), fill=BROWN)
    d.rectangle([x - 4, H - 78, x + 292, H - 30], fill=(0, 0, 0))
    d.text((x + 8, H - 69), "Personnage IA", font=ImageFont.truetype(F + "Inter-SemiBold.otf", 30), fill=(255, 255, 255))
    img.save(out, quality=92)


if __name__ == "__main__":
    main()
