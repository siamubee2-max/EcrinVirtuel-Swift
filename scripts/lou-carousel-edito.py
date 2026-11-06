"""Lou carousels, 'éditorial' style: full-bleed photos, magazine typography, no paper/tape.

Renders carrousels 01 to 05 into docs/marketing/lou/carrousel-0X/edito/ from the
photos already in each carousel folder. Needs Pillow, the Cormorant fonts in
docs/marketing/lou/fonts/ and Inter (system font).

Usage: python3 scripts/lou-carousel-edito.py [01 02 ...]   (default: all)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps

REPO = Path(__file__).resolve().parent.parent / "docs" / "marketing" / "lou"
W, H = 1080, 1350
IVORY = (246, 240, 230)
INK = (20, 18, 17)
GOLD = (201, 162, 75)
F = REPO / "fonts"
SHOT = REPO.parent.parent / "appstore" / "screenshots-framed" / "01-essayage-framed.png"
INTER = Path("/usr/share/fonts/opentype/inter")

SERIF_I = lambda s: ImageFont.truetype(str(F / "Cormorant-MediumItalic.ttf"), s)
SERIF = lambda s: ImageFont.truetype(str(F / "Cormorant-Medium.ttf"), s)
SEMI = lambda s: ImageFont.truetype(str(INTER / "Inter-SemiBold.otf"), s)
MED = lambda s: ImageFont.truetype(str(INTER / "Inter-Medium.otf"), s)


def grade(img):
    """Light editorial grade: a touch of contrast, fine grain."""
    img = ImageEnhance.Contrast(img.convert("RGB")).enhance(1.04)
    g = Image.merge("RGB", [Image.effect_noise(img.size, 22).convert("L")] * 3)
    return Image.blend(img, g, 0.045)


def load(path, trim=0.022):
    img = Image.open(path)
    dx, dy = int(img.width * trim), int(img.height * trim)  # the generator sometimes adds a dark frame
    return img.crop((dx, dy, img.width - dx, img.height - dy))


def bleed(path, size=(W, H), centering=(0.5, 0.4)):
    return grade(ImageOps.fit(load(path), size, Image.LANCZOS, centering=centering)).convert("RGBA")


def shade(c, start, strength=235, top=0):
    """Dark gradient from `start` to the bottom (and an optional soft one at the top)."""
    m = Image.new("L", (1, H), 0)
    for y in range(H):
        a = 0
        if y > start:
            t = (y - start) / (H - start)
            a = int(strength * min(1, t * 1.25) ** 1.4)
        if y < top:
            a = max(a, int(110 * (1 - y / top) ** 1.6))
        m.putpixel((0, y), a)
    layer = Image.new("RGBA", (W, H), INK + (0,))
    layer.putalpha(m.resize((W, H)))
    c.alpha_composite(layer)


def tracked(d, xy, s, f, fill, spacing=4, anchor="l"):
    x, y = xy
    width = sum(f.getlength(ch) for ch in s) + spacing * (len(s) - 1)
    if anchor == "r":
        x -= width
    elif anchor == "m":
        x -= width / 2
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += f.getlength(ch) + spacing


def wrap(s, f, width):
    lines, cur = [], ""
    for w in s.split(" "):
        t = (cur + " " + w).strip()
        if f.getlength(t) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def chrome(c, n, total, kicker, dark=True):
    d = ImageDraw.Draw(c)
    col = IVORY if dark else INK
    tracked(d, (64, 60), kicker, SEMI(21), col, spacing=5)
    tracked(d, (W - 64, 60), f"{n:02d} / {total:02d}", SEMI(21), col, spacing=4, anchor="r")
    if n < total:
        tracked(d, (W - 64, H - 78), "GLISSE  →", SEMI(21), GOLD, spacing=5, anchor="r")


def chips(c, x, y, colors, w=92, h=40, gap=12):
    d = ImageDraw.Draw(c)
    for i, col in enumerate(colors):
        d.rectangle([x + i * (w + gap), y, x + i * (w + gap) + w, y + h], fill=col, outline=IVORY, width=2)


def content(path, n, total, kicker, label, title, tip, colors, out, ph=960):
    """Photo on top (jewellery and outfit stay clear of text), copy on an ink band below."""
    c = Image.new("RGBA", (W, H), INK + (255,))
    photo = bleed(path, (W, ph), (0.5, 0.3))
    fade = Image.new("L", (1, ph), 255)
    for y in range(ph - 170, ph):
        fade.putpixel((0, y), int(255 * (1 - (y - ph + 170) / 170) ** 1.3))
    photo.putalpha(fade.resize((W, ph)))
    c.alpha_composite(photo)
    top = Image.new("RGBA", (W, 160), INK + (0,))
    top.putalpha(Image.linear_gradient("L").rotate(180).resize((W, 160)).point(lambda v: int(v * 0.45)))
    c.alpha_composite(top)
    d = ImageDraw.Draw(c)
    tracked(d, (64, ph - 40), label, SEMI(22), GOLD, spacing=6)
    if colors:
        chips(c, W - 64 - len(colors) * 104 + 12, ph - 50, colors)
    size = 100
    while SERIF_I(size).getlength(title) > W - 128:
        size -= 4
    d.text((60, ph - 10 + (100 - size) // 2), title, font=SERIF_I(size), fill=IVORY)
    d.line([(64, ph + 120), (164, ph + 120)], fill=GOLD, width=3)
    for i, line in enumerate(wrap(tip, MED(31), W - 128)):
        d.text((64, ph + 146 + i * 44), line, font=MED(31), fill=(232, 226, 216))
    chrome(c, n, total, kicker)
    c.convert("RGB").save(out, quality=94)


def cover(path, total, kicker, title, sub, colors, out):
    c = bleed(path)
    shade(c, 420, strength=245, top=200)
    d = ImageDraw.Draw(c)
    tf = SERIF_I(136)
    lines = title.split("\n")
    y = H - 300 - len(lines) * 126
    for i, line in enumerate(lines):
        d.text((56, y + i * 126), line, font=tf, fill=IVORY)
    d.line([(64, H - 262), (164, H - 262)], fill=GOLD, width=3)
    d.text((64, H - 230), sub, font=MED(36), fill=(232, 226, 216))
    if colors:
        chips(c, 64, y - 76, colors, w=70, h=34, gap=10)
    chrome(c, 1, total, kicker)
    c.convert("RGB").save(out, quality=94)


def secret(n, total, kicker, label, title, body, punch, out):
    """Ink slide: copy on the left, a real App Store screenshot of the app on the right."""
    c = Image.new("RGB", (W, H), INK)
    c = Image.blend(c, Image.merge("RGB", [Image.effect_noise((W, H), 20).convert("L")] * 3), 0.04).convert("RGBA")
    shot = Image.open(SHOT).convert("RGBA")
    sh = 1040
    shot = shot.resize((int(shot.width * sh / shot.height), sh), Image.LANCZOS)
    c.alpha_composite(shot, (W - 50 - shot.width, 160))
    d = ImageDraw.Draw(c)
    x, col = 64, W - 64 - shot.width - 80
    tracked(d, (x, 250), label, SEMI(22), GOLD, spacing=6)
    y = 300
    for line in title.split("\n"):
        d.text((x - 4, y), line, font=SERIF_I(86), fill=IVORY)
        y += 92
    d.line([(x, y + 34), (x + 100, y + 34)], fill=GOLD, width=3)
    y += 70
    for line in wrap(body, MED(31), col):
        d.text((x, y), line, font=MED(31), fill=(232, 226, 216))
        y += 44
    y += 60
    for line in punch:
        d.text((x, y), line, font=SERIF(52), fill=IVORY)
        y += 64
    d.text((x, y + 50), "L'Écrin Virtuel", font=SERIF_I(50), fill=GOLD)
    chrome(c, n, total, kicker)
    c.convert("RGB").save(out, quality=94)


def ending(paths, total, kicker, title, line, out, pill="Enregistre ce post pour ta prochaine tenue"):
    c = Image.new("RGB", (W, H), INK)
    c = Image.blend(c, Image.merge("RGB", [Image.effect_noise((W, H), 20).convert("L")] * 3), 0.04).convert("RGBA")
    tw, th, gap = 300, 375, 26
    x0 = (W - 3 * tw - 2 * gap) // 2
    for i, p in enumerate(paths):
        img = grade(ImageOps.fit(load(p), (tw, th), Image.LANCZOS, centering=(0.5, 0.35))).convert("RGBA")
        c.alpha_composite(img, (x0 + i * (tw + gap), 170))
    d = ImageDraw.Draw(c)
    d.text((W / 2, 700), title, font=SERIF_I(104), fill=IVORY, anchor="mm")
    d.text((W / 2, 800), line, font=MED(36), fill=GOLD, anchor="mm")
    d.line([(W / 2 - 50, 880), (W / 2 + 50, 880)], fill=GOLD, width=2)
    d.text((W / 2, 945), "L'Écrin Virtuel", font=SERIF(64), fill=IVORY, anchor="mm")
    tracked(d, (W / 2, 1000), "GRATUIT SUR L'APP STORE", SEMI(22), (200, 192, 180), spacing=6, anchor="m")
    half = MED(27).getlength(pill) / 2 + 50
    d.rounded_rectangle([W / 2 - half, 1130, W / 2 + half, 1210], radius=40, outline=GOLD, width=2)
    d.text((W / 2, 1170), pill, font=MED(27), fill=IVORY, anchor="mm")
    chrome(c, total, total, kicker)
    c.convert("RGB").save(out, quality=94)


def sheet(folder, dest):
    thumbs = [Image.open(p).resize((360, 450)) for p in sorted(folder.glob("0*.jpg"))]
    s = Image.new("RGB", (360 * 3 + 40, 450 * 2 + 30), (60, 60, 60))
    for i, t in enumerate(thumbs):
        s.paste(t, (10 + (i % 3) * 370, 10 + (i // 3) * 460))
    s.save(dest, quality=88)


def c01(out):
    P = REPO / "carrousel-01" / "photos"
    k = "LOU · CETTE SEMAINE"
    cover(P / "a-sol.jpg", 6, k, "Ce que j'ai\nosé essayer", "Cette semaine, en vrai.", None, out / "01-couverture.jpg")
    content(P / "b-rouge.jpg", 2, 6, k, "OSÉ N°1", "Le rouge, enfin.",
            "Dix ans que je me disais «\u00a0c'est pas pour moi\u00a0». Verdict\u00a0? Canon.", [(196, 30, 45)], out / "02-le-rouge.jpg")
    content(P / "c-mains.jpg", 3, 6, k, "LES BIJOUX", "Faits main",
            "Des pierres brutes, de l'or fin. Derrière chaque bijou, il y a des mains.", None, out / "03-faits-main.jpg")
    secret(4, 6, k, "MON SECRET", "1 photo,\net j'essaie tout.", "La robe, la bague, la couleur interdite.",
           ["Sans cabine.", "Sans vendeuse.", "Sans regret."], out / "04-mon-secret.jpg")
    content(P / "d-cafe.jpg", 5, 6, k, "À TOI", "Et toi ?",
            "C'est quoi la couleur que tu n'as jamais osé porter ? Dis-le-moi en commentaire, je la teste pour toi.",
            None, out / "05-et-toi.jpg")
    ending([P / "a-sol.jpg", P / "b-rouge.jpg", P / "d-cafe.jpg"], 6, k, "Ose.", "C'est gratuit d'essayer.",
           out / "06-ose.jpg", pill="Dis-moi ta couleur en commentaire")


def c02(out):
    P = REPO / "carrousel-02" / "photos"
    k = "LOU · LA BAGUE À 3 000 €"
    cover(P / "a-bague.jpg", 6, k, "La bague\nà 3 000 €", "Je l'ai essayée… sans entrer en boutique.", None,
          out / "01-couverture.jpg")
    content(P / "b-vitrine.jpg", 2, 6, k, "LE MALAISE", "En boutique ?",
            "J'ose même pas pousser la porte. Le regard du vendeur, le prix qu'on n'ose pas demander… Tu connais\u00a0?",
            None, out / "02-la-vitrine.jpg")
    content(P / "c-main.jpg", 3, 6, k, "LE VERDICT", "Ça me va ?",
            "Ça me va pas ? Au moins, maintenant, je sais.", None, out / "03-je-sais.jpg")
    secret(4, 6, k, "LE SECRET", "1 photo,\net je sais.",
           "Le bijou de mes rêves sur ma main, et je vois tout de suite si c'est «\u00a0moi\u00a0».",
           ["Zéro pression.", "Zéro vendeur.", "Zéro regret."], out / "04-le-secret.jpg")
    content(P / "d-ecrin.jpg", 5, 6, k, "MESSIEURS", "Prenez des notes.",
            "Essayez-le sur sa photo avant d'offrir (avec son accord, évidemment).", None, out / "05-messieurs.jpg")
    ending([P / "a-bague.jpg", P / "c-main.jpg", P / "d-ecrin.jpg"], 6, k, "Ose.", "C'est gratuit d'essayer.",
           out / "06-ose.jpg", pill="Envoie ce post à qui doit le voir")


def c03(out):
    P = REPO / "carrousel-03" / "photos"
    k = "LOU · SPÉCIAL MESSIEURS"
    cover(P / "a-montres.jpg", 6, k, "Spécial\nmessieurs", "Celui-là, c'est pour vous.", None, out / "01-couverture.jpg")
    content(P / "b-poignet.jpg", 2, 6, k, "LA MONTRE", "Classique ou audacieuse ?",
            "Arrêtez de deviner. 1 photo de votre poignet, et vous voyez les deux.", None, out / "02-la-montre.jpg")
    content(P / "c-chemise.jpg", 3, 6, k, "LA CHEMISE", "Bleu cobalt",
            "Celle que vous n'avez jamais osé porter. Spoiler\u00a0: elle vous va.", [(30, 70, 170)], out / "03-la-chemise.jpg")
    secret(4, 6, k, "COMMENT ?", "1 photo\nde vous.", "Et vous essayez la montre, la chemise, la chevalière.",
           ["Pas de vendeur.", "Pas de cabine.", "Pas de risque."], out / "04-comment.jpg")
    content(P / "d-cadeau.jpg", 5, 6, k, "POUR ELLE", "Et le cadeau ?",
            "Essayez-le sur sa photo avant d'offrir (avec son accord, évidemment).", None, out / "05-pour-elle.jpg")
    ending([P / "a-montres.jpg", P / "b-poignet.jpg", P / "c-chemise.jpg"], 6, k, "Allez, osez.",
           "C'est gratuit d'essayer.", out / "06-osez.jpg", pill="Envoyez ce post à un ami qui hésite")


def c04(out):
    P = REPO / "carrousel-04" / "photos"
    k = "LE GUIDE DE LOU · COULEURS"
    cols = {"violet-gris": [(128, 92, 170), (200, 200, 200)], "rouge-rose": [(196, 30, 45), (240, 182, 196)],
            "vert-cobalt": [(0, 128, 90), (30, 70, 170)], "moutarde-bordeaux": [(214, 160, 40), (110, 25, 45)]}
    cover(P / "rouge-rose.jpg", 6, k, "4 couleurs\nque tu n'oses pas", "et qui marchent vraiment ensemble.",
          sum(cols.values(), []), out / "01-couverture.jpg")
    rows = [("violet-gris", "Violet + gris clair", "Le gris calme le violet, le violet réveille le gris. Raffiné, jamais tristounet."),
            ("rouge-rose", "Rouge + rose", "L'interdit qui fait tourner les têtes. Garde un des deux en pastel, et c'est gagné."),
            ("vert-cobalt", "Émeraude + cobalt", "Deux couleurs froides, zéro faute : même intensité, matières différentes."),
            ("moutarde-bordeaux", "Moutarde + bordeaux", "L'automne version chic. Ajoute de l'or, jamais de l'argent.")]
    for i, (f, t, tip) in enumerate(rows):
        content(P / f"{f}.jpg", i + 2, 6, k, f"COMBINAISON N°{i + 1}", t, tip, cols[f], out / f"0{i + 2}-{f}.jpg")
    ending([P / "rouge-rose.jpg", P / "vert-cobalt.jpg", P / "violet-gris.jpg"], 6, k,
           "Laquelle tu oses ?", "Essaie-les sur toi, en 1 photo.", out / "06-ose.jpg")


def c05(out):
    P = REPO / "carrousel-05" / "photos"
    k = "LE GUIDE DE LOU · COLLIERS"
    cover(P / "colV-pendentif.jpg", 6, k, "Quel collier\npour ton décolleté ?", "La règle que personne ne m'avait apprise.",
          None, out / "01-couverture.jpg")
    rows = [("colV-pendentif", "Col V", "Un pendentif qui suit le V : la chaîne finit juste au-dessus de la pointe."),
            ("rond-sautoir", "Col rond", "Un sautoir long, bien en dessous. Jamais un collier qui «\u00a0coupe\u00a0» l'encolure."),
            ("bustier-ras", "Épaules dénudées", "Un ras-du-cou fin. On montre la clavicule, on ne la cache pas."),
            ("roule-creoles", "Col roulé", "Pas de collier : des créoles XXL. Le bijou remonte vers le visage.")]
    for i, (f, t, tip) in enumerate(rows):
        content(P / f"{f}.jpg", i + 2, 6, k, f"RÈGLE N°{i + 1}", t, tip, None, out / f"0{i + 2}-{f}.jpg")
    ending([P / "colV-pendentif.jpg", P / "bustier-ras.jpg", P / "roule-creoles.jpg"], 6, k,
           "Et toi, quel décolleté ?", "Essaie le bon collier sur ta photo.", out / "06-ose.jpg")


if __name__ == "__main__":
    jobs = {"01": c01, "02": c02, "03": c03, "04": c04, "05": c05}
    for num in sys.argv[1:] or jobs:
        name, fn = f"carrousel-{num}", jobs[num]
        o = REPO / name / "edito"
        o.mkdir(parents=True, exist_ok=True)
        fn(o)
        sheet(o, o / "planche.jpg")
        print(o)
