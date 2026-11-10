#!/usr/bin/env python3
"""Assemble the 16:9 YouTube explainer (about 3 min): Lou's MIMI voice-over over app footage.

Usage: python3 scripts/lou-youtube-explainer.py --rec1 A.mp4 --rec2 B.mp4 --site DIR --out out.mp4 [--work DIR]
  --rec1/--rec2 : the two iPhone screen recordings (not stored in the repo: they hold private screens)
  --site        : folder with site-home/ecrin/projets/liste/prix.png (Playwright captures of inferencevision.store)
The voice is built from pieces of the first take (VOICE_ORIG) and four new blocks (voix-blocs/bloc-A..D.mp3).
Each piece gets its own visuals (PLAN). Vertical footage is centred over a blurred copy of itself.
Needs ffmpeg with libass and Pillow.
"""
import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1920, 1080, 25
LOU = "docs/marketing/lou/"
SHOTS = "docs/appstore/screenshots-framed/"
YT = "docs/marketing/youtube/"
ORIG = YT + "voix-lou-video-longue.mp3"
BLOC = YT + "voix-blocs/bloc-%s.mp3"
GAP, END = 0.35, 2.5

# (audio file, start, end) ; None = whole file
PIECES = [
    ("orig", 0.0, 5.0), ("orig", 11.54, 22.0), ("A", None, None), ("orig", 22.52, 29.75),
    ("orig", 30.18, 46.39), ("B", None, None), ("orig", 46.79, 55.2), ("C", None, None),
    ("D", None, None), ("orig", 67.24, 82.36),
]

# Visuals per piece: list of (weight, kind, args, chip). kind: img path | vid rec src_start src_dur
PLAN = [
    [(1, "img", LOU + "carrousel-02/photos/a-bague.jpg", None), (1, "img", LOU + "carrousel-02/photos/c-main.jpg", None)],
    [(1, "site", "site-home.png", "Un **studio**\\Nindépendant\\Nbelge"), (1, "site", "site-ecrin.png", None)],
    [(1.0, "site", "site-home.png", "Moins de **bruit**\\Nplus d'**usage**"), (1.2, "site", "site-projets.png", "Des applications\\N**indépendantes**")],
    [(1, "img", LOU + "carrousel-02/photos/b-vitrine.jpg", "Le **problème**")],
    [(3.5, "vid", ("rec2", 117, 12), "**1** · Ta photo"), (4.0, "vid", ("rec1", 17, 28), "**2** · Une pièce"),
     (6.5, "vid", ("rec2", 521, 12), "**3** · Le rendu"), (2.21, "vid", ("rec2", 545, 7), "**4** · Comparer")],
    [(16.3, "img", SHOTS + "06-quicktryon-framed.png", "**Photographie**\\Nla pièce"),
     (10.6, "vid", ("rec1", 17, 60), "Bijoux, vêtements,\\N**accessoires**"),
     (3.75, "vid", ("rec2", 76, 14), "**3 vues** :\\Nface, 3/4, profil"), (3.75, "vid", ("rec2", 205, 14), None),
     (4.5, "vid", ("rec2", 440, 7), "La **tenue complète**"), (5.2, "vid", ("rec2", 521, 12), None),
     (4.7, "vid", ("rec2", 545, 7), "**Avant** / **après**"),
     (4.4, "site", "site-liste.png", "**Côte à côte**")],
    [(1.0, "vid", ("rec1", 78, 8), "Mon **Écrin**"), (0.9, "img", SHOTS + "05-lookdujour-framed.png", "Le **styliste** météo")],
    [(7.5, "vid", ("rec1", 93, 13), "Un espace **créateurs**"),
     (15.5, "img", LOU + "carrousel-01/photos/d-cafe.jpg", "Un mot\\Nd'**honnêteté**"),
     (6.7, "img", SHOTS + "01-essayage-framed.png", "Comment **commencer**")],
    [(1, "img", LOU + "carrousel-01/photos/b-rouge.jpg", "Des **idées**\\Npour t'amuser")],
    [(6.76, "site", "site-prix.png", "**Gratuit**\\Npour découvrir"), (8.36, "img", LOU + "carrousel-01/photos/a-sol.jpg", "Lien dans la\\N**description**")],
]


def run(cmd):
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)


def vfilter(fg_expr, chain):
    return (f"{chain},split=2[a][b];[a]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
            f"boxblur=40:6,eq=brightness=-0.12:saturation=0.9[bg];[b]{fg_expr}[fg];"
            f"[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p")


def image_seg(path, dur, out):
    w, h = Image.open(path).size
    fw = round(1000 * w / h / 2) * 2
    fg = f"zoompan=z='min(1+0.0005*on,1.08)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={round(dur * FPS)}:s={fw}x1000:fps={FPS}"
    run(["ffmpeg", "-y", "-i", str(path), "-filter_complex", vfilter(fg, "[0:v]format=rgba"),
         "-t", f"{dur:.3f}", "-r", str(FPS), "-c:v", "libx264", "-crf", "18", "-an", str(out)])


def video_seg(src, start, src_dur, out_dur, out):
    chain = f"[0:v]fps={FPS},setpts=(PTS-STARTPTS)*{out_dur / src_dur:.5f}"
    run(["ffmpeg", "-y", "-ss", str(start), "-t", str(src_dur), "-i", str(src), "-filter_complex",
         vfilter("scale=-2:1000", chain), "-t", f"{out_dur:.3f}", "-r", str(FPS), "-c:v", "libx264", "-crf", "20", "-an", str(out)])


def end_card(path):
    img = Image.new("RGB", (W, H), (237, 230, 218))
    d = ImageDraw.Draw(img)
    f = lambda n, s: ImageFont.truetype("/usr/share/fonts/opentype/inter/" + n, s)
    d.text((W // 2, 420), "L'Écrin Virtuel", font=f("Inter-ExtraBold.otf", 130), fill=(107, 70, 48), anchor="mm")
    d.text((W // 2, 560), "Ose. C'est gratuit d'essayer.", font=f("Inter-ExtraBold.otf", 56), fill=(201, 162, 75), anchor="mm")
    d.text((W // 2, 700), "Disponible sur l'App Store · inferencevision.store/ecrin", font=f("Inter-Medium.otf", 40), fill=(107, 70, 48), anchor="mm")
    d.text((W // 2, 900), "Lou est un personnage créé par IA", font=f("Inter-Medium.otf", 32), fill=(107, 70, 48), anchor="mm")
    img.save(path)


def ts(t):
    return f"{int(t // 3600)}:{int(t % 3600 // 60):02d}:{t % 60:05.2f}"


def build_ass(path, chips, total):
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Chip,Inter ExtraBold,66,&H00FFFFFF&,&H00FFFFFF&,&H00000000&,&H64000000&,1,0,0,0,100,100,0,0,1,4,3,4,90,1050,0,1
Style: Label,Inter SemiBold,32,&H00FFFFFF&,&H00FFFFFF&,&H00000000&,&H78000000&,0,0,0,0,100,100,0,0,3,10,0,7,44,44,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

    def fmt(text):
        out, on = "", False
        for part in text.split("**"):
            out += ("{\\c&H004BA2C9&}" if on else "{\\c&H00FFFFFF&}") + part
            on = not on
        return out

    lines = [f"Dialogue: 0,{ts(0)},{ts(total - END)},Label,,0,0,0,,Personnage IA"]
    lines += [f"Dialogue: 0,{ts(a)},{ts(b)},Chip,,0,0,0,,{fmt(t)}" for a, b, t in chips]
    Path(path).write_text(head + "\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rec1", required=True)
    ap.add_argument("--rec2", required=True)
    ap.add_argument("--site", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--work", default="/tmp/lou-yt")
    a = ap.parse_args()
    w = Path(a.work)
    w.mkdir(parents=True, exist_ok=True)
    recs, site = {"rec1": a.rec1, "rec2": a.rec2}, Path(a.site)

    # 1. voice: pieces joined with a short pause
    inputs, filt, labels, spans = [], [], [], []
    for i, (name, s, e) in enumerate(PIECES):
        src = ORIG if name == "orig" else BLOC % name
        inputs += ["-i", src]
        dur = e - s if s is not None else float(subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src]).strip())
        trim = f"atrim={s}:{e}," if s is not None else ""
        filt.append(f"[{i}:a]aresample=44100,aformat=channel_layouts=mono,{trim}asetpts=PTS-STARTPTS,"
                    f"afade=t=in:d=0.02,afade=t=out:st={dur - 0.02:.3f}:d=0.02[v{i}]")
        labels.append(f"[v{i}]")
        spans.append(dur)
        if i < len(PIECES) - 1:
            filt.append(f"anullsrc=r=44100:cl=mono,atrim=0:{GAP}[g{i}]")
            labels.append(f"[g{i}]")
    voice = w / "voice.wav"
    run(["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(filt) + ";" + "".join(labels) + f"concat=n={len(labels)}:v=0:a=1[o]", "-map", "[o]", str(voice)])

    # 2. visuals: each piece's span (plus the pause after it) is split by weight
    segs, chips, t = [], [], 0.0
    for i, (dur, plan) in enumerate(zip(spans, PLAN)):
        span = dur + (GAP if i < len(PIECES) - 1 else 0)
        total_w = sum(p[0] for p in plan)
        for j, (wt, kind, arg, chip) in enumerate(plan):
            d = span * wt / total_w
            out = w / f"p{i}_{j}.mp4"
            if kind == "img":
                image_seg(arg, d, out)
            elif kind == "site":
                image_seg(site / arg, d, out)
            else:
                video_seg(recs[arg[0]], arg[1], arg[2], d, out)
            segs.append(out)
            if chip:
                chips.append((t, t + d, chip))
            t += d
    end_png, endv = w / "end.png", w / "end.mp4"
    end_card(end_png)
    run(["ffmpeg", "-y", "-loop", "1", "-i", str(end_png), "-t", str(END), "-r", str(FPS), "-vf", "format=yuv420p", "-c:v", "libx264", "-crf", "18", str(endv)])
    segs.append(endv)
    lst = w / "list.txt"
    lst.write_text("".join(f"file '{p.resolve()}'\n" for p in segs))
    body = w / "body.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(body)])
    total = t + END
    ass = w / "caps.ass"
    build_ass(ass, chips, total)
    run(["ffmpeg", "-y", "-i", str(body), "-i", str(voice), "-vf", f"ass={ass}", "-af", f"apad=whole_dur={total:.2f},loudnorm=I=-14:TP=-1.5",
         "-t", f"{total:.2f}", "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(a.out)])
    print(a.out, round(total, 1))


if __name__ == "__main__":
    main()
