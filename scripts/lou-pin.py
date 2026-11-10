#!/usr/bin/env python3
"""Build a Pinterest pin (1000x1500, 2:3) from one of Lou's photos.

Usage: python3 scripts/lou-pin.py plan.json
Plan: {"pins": [{"photo": path, "title": "...", "sub": "...", "out": path, "focus_y": 0.35, "zoom": 1.0}]}
Needs Pillow. Title and sub are burned over a bottom gradient; the AI disclosure
and brand line are always added.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1000, 1500
FONTS = "/usr/share/fonts/opentype/inter/"
IVORY, GOLD = (237, 230, 218), (201, 162, 75)


def font(name, size):
    return ImageFont.truetype(FONTS + name, size)


def wrap(draw, text, fnt, width):
    lines, cur = [], ""
    for word in text.split(" "):
        test = (cur + " " + word).strip()
        if draw.textlength(test, font=fnt) <= width:
            cur = test
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def build(p):
    img = Image.open(p["photo"]).convert("RGB")
    scale = max(W / img.width, H / img.height) * p.get("zoom", 1.0)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    top = int((img.height - H) * p.get("focus_y", 0.35))
    img = img.crop(((img.width - W) // 2, top, (img.width - W) // 2 + W, top + H))
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(H // 2, H):
        gd.line([(0, y), (W, y)], fill=(20, 17, 14, int(235 * ((y - H // 2) / (H / 2)) ** 1.4)))
    img = Image.alpha_composite(img.convert("RGBA"), grad)
    d = ImageDraw.Draw(img)
    tf, sf = font("Inter-ExtraBold.otf", 78), font("Inter-Medium.otf", 36)
    lines = wrap(d, p["title"], tf, W - 130)
    sub = wrap(d, p["sub"], sf, W - 130)
    y = H - 150 - 48 * len(sub) - 96 * len(lines)
    for ln in lines:
        d.text((65, y), ln, font=tf, fill=IVORY)
        y += 96
    d.line([(65, y + 10), (165, y + 10)], fill=GOLD, width=5)
    y += 34
    for ln in sub:
        d.text((65, y), ln, font=sf, fill=IVORY)
        y += 48
    d.text((65, H - 95), "L'ÉCRIN VIRTUEL", font=font("Inter-Bold.otf", 28), fill=GOLD)
    d.text((W - 65, H - 95), "Lou est un personnage créé par IA", font=font("Inter-Medium.otf", 24),
           fill=IVORY, anchor="ra")
    Path(p["out"]).parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(p["out"], quality=92)


if __name__ == "__main__":
    for pin in json.load(open(sys.argv[1]))["pins"]:
        build(pin)
        print(pin["out"])
