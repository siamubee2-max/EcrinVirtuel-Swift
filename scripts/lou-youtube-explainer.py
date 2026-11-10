#!/usr/bin/env python3
"""Assemble the 16:9 YouTube explainer: Lou's MIMI voice-over over app footage.

Usage: python3 scripts/lou-youtube-explainer.py --rec1 A.mp4 --rec2 B.mp4 --site DIR --out out.mp4 [--work DIR]
  --rec1/--rec2 : the two iPhone screen recordings (not stored in the repo: they hold private screens)
  --site        : folder with site-home/ecrin/ia/prix.png (Playwright captures of inferencevision.store)
Section boundaries are the pauses of docs/marketing/youtube/voix-lou-video-longue.mp3.
Vertical footage is centred over a blurred copy of itself. Needs ffmpeg with libass and Pillow.
"""
import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1920, 1080, 25
LOU = "docs/marketing/lou/"
SHOTS = "docs/appstore/screenshots-framed/"
VOICE = "docs/marketing/youtube/voix-lou-video-longue.mp3"
B = [0, 11.3, 22.2, 29.97, 46.6, 55.4, 67.05, 74.0, 82.36]   # section boundaries in the voice
END = 2.5


def run(cmd):
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)


def vfilter(fw_expr, src_chain):
    return (f"{src_chain},split=2[a][b];[a]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
            f"boxblur=40:6,eq=brightness=-0.12:saturation=0.9[bg];[b]{fw_expr}[fg];"
            f"[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p")


def image_seg(path, dur, out):
    w, h = Image.open(path).size
    fw = round(1000 * w / h / 2) * 2
    frames = round(dur * FPS)
    fg = (f"zoompan=z='min(1+0.0005*on,1.08)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s={fw}x1000:fps={FPS}")
    run(["ffmpeg", "-y", "-i", str(path), "-filter_complex", vfilter(fg, "[0:v]format=rgba,fps=25") .replace("[0:v]format=rgba,fps=25,split=2", "[0:v]format=rgba,split=2"),
         "-t", f"{dur:.3f}", "-r", str(FPS), "-c:v", "libx264", "-crf", "18", "-an", str(out)])


def video_seg(src, start, src_dur, out_dur, out):
    chain = f"[0:v]fps={FPS},setpts=(PTS-STARTPTS)*{out_dur / src_dur:.5f}"
    run(["ffmpeg", "-y", "-ss", str(start), "-t", str(src_dur), "-i", str(src), "-filter_complex",
         vfilter("scale=-2:1000", chain), "-t", f"{out_dur:.3f}", "-r", str(FPS), "-c:v", "libx264", "-crf", "20", "-an", str(out)])


def end_card(path):
    img = Image.new("RGB", (W, H), (237, 230, 218))
    d = ImageDraw.Draw(img)
    F = "/usr/share/fonts/opentype/inter/"
    f = lambda n, s: ImageFont.truetype(F + n, s)
    d.text((W // 2, 420), "L'Écrin Virtuel", font=f("Inter-ExtraBold.otf", 130), fill=(107, 70, 48), anchor="mm")
    d.text((W // 2, 560), "Ose. C'est gratuit d'essayer.", font=f("Inter-ExtraBold.otf", 56), fill=(201, 162, 75), anchor="mm")
    d.text((W // 2, 700), "Disponible sur l'App Store · inferencevision.store/ecrin", font=f("Inter-Medium.otf", 40), fill=(107, 70, 48), anchor="mm")
    d.text((W // 2, 900), "Lou est un personnage créé par IA", font=f("Inter-Medium.otf", 32), fill=(107, 70, 48), anchor="mm")
    img.save(path)


def ass_time(t):
    return f"{int(t // 3600)}:{int(t % 3600 // 60):02d}:{t % 60:05.2f}"


def build_ass(path, total):
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
    gold = "{\\c&H004BA2C9&}"
    white = "{\\c&H00FFFFFF&}"

    def chip(text):
        out, on = "", False
        for part in text.split("**"):
            out += (gold if on else white) + part
            on = not on
        return out

    s4 = B[3]
    items = [
        (B[1], B[2], "Une **studio**\\Nindépendant\\Nbelge".replace("Une **studio**", "Un **studio**")),
        (B[2], B[3], "Le **problème**"),
        (s4, s4 + 3.5, "**1** · Ta photo"),
        (s4 + 3.5, s4 + 7.5, "**2** · Une pièce"),
        (s4 + 7.5, s4 + 14.0, "**3** · Le rendu"),
        (s4 + 14.0, B[4], "**4** · Comparer"),
        (B[4], B[4] + 4.4, "Mon **Écrin**"),
        (B[4] + 4.4, B[5], "Le **styliste**\\Nmétéo"),
        (B[5], B[6], "L'IA, en\\N**toute transparence**"),
        (B[6], B[7], "**Gratuit**\\Npour découvrir"),
        (B[7], B[8], "Lien dans la\\N**description**"),
    ]
    lines = [f"Dialogue: 0,{ass_time(0)},{ass_time(total - END)},Label,,0,0,0,,Personnage IA"]
    for a, b, t in items:
        lines.append(f"Dialogue: 0,{ass_time(a)},{ass_time(b)},Chip,,0,0,0,,{chip(t)}")
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
    site = Path(a.site)
    d = [B[i + 1] - B[i] for i in range(8)]
    segs = []

    def add(name, fn, *args):
        out = w / f"{name}.mp4"
        fn(*args, out)
        segs.append(out)

    add("s1a", image_seg, LOU + "carrousel-02/photos/a-bague.jpg", d[0] / 2)
    add("s1b", image_seg, LOU + "carrousel-02/photos/c-main.jpg", d[0] / 2)
    add("s2a", image_seg, site / "site-home.png", d[1] / 2)
    add("s2b", image_seg, site / "site-ecrin.png", d[1] / 2)
    add("s3", image_seg, LOU + "carrousel-02/photos/b-vitrine.jpg", d[2])
    add("s4a", video_seg, a.rec2, 117, 12, 3.5)
    add("s4b", video_seg, a.rec1, 17, 28, 4.0)
    add("s4c", video_seg, a.rec2, 521, 12, 6.5)
    add("s4d", video_seg, a.rec2, 545, 7, d[3] - 14.0)
    add("s5a", image_seg, SHOTS + "02-garderobe-framed.png", 4.4)
    add("s5b", image_seg, SHOTS + "05-lookdujour-framed.png", d[4] - 4.4)
    add("s6", image_seg, site / "site-ia.png", d[5])
    add("s7", image_seg, site / "site-prix.png", d[6])
    add("s8", image_seg, LOU + "carrousel-01/photos/a-sol.jpg", d[7])
    end_png = w / "end.png"
    end_card(end_png)
    endv = w / "end.mp4"
    run(["ffmpeg", "-y", "-loop", "1", "-i", str(end_png), "-t", str(END), "-r", str(FPS), "-vf", "format=yuv420p", "-c:v", "libx264", "-crf", "18", str(endv)])
    segs.append(endv)
    lst = w / "list.txt"
    lst.write_text("".join(f"file '{p.resolve()}'\n" for p in segs))
    body = w / "body.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(body)])
    total = B[-1] + END
    ass = w / "caps.ass"
    build_ass(ass, total)
    run(["ffmpeg", "-y", "-i", str(body), "-i", VOICE, "-vf", f"ass={ass}", "-af", f"apad=whole_dur={total},loudnorm=I=-14:TP=-1.5",
         "-t", f"{total:.2f}", "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(a.out)])
    print(a.out)


if __name__ == "__main__":
    main()
