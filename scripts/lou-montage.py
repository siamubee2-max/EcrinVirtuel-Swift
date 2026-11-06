#!/usr/bin/env python3
"""Assemble one of Lou's videos from its lip-synced shots.

Input is a JSON plan: an ordered list of shots, each with the clip URL (or a
local path) and its burned-in caption, plus the end card text. The script:

  1. downloads every clip (cached in --work);
  2. normalises each one to 1080x1920, 25 fps, AAC 48 kHz stereo;
  3. erases any text baked into the source frames ("erase": [[x, y, w, h], ...]
     in source pixels, interpolated from the surrounding pixels) or crops it
     out ("crop": [x, y, w, h]), then burns the caption (keywords between
     ** ** in gold #C9A24B, or the plan's "accent" colour) and the
     "Personnage IA" label (top left, whole video) via libass;
     an optional "overlay" {"image": path-or-url, "height": 820, "x": "right"|px,
     "y": 300, "from": 0.5, "to": 3.0} puts a picture (e.g. a real app screenshot)
     over the shot between two instants, under the captions;
  4. builds the ivory end card with the AI disclosure;
  5. concatenates everything into a single H.264 MP4, loudness-normalised
     to -14 LUFS.

Needs ffmpeg with libass. Usage:
  python3 scripts/lou-montage.py docs/marketing/lou/montage-video-01.json out.mp4
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

W, H, FPS = 1080, 1920, 25
GOLD = "&H004BA2C9&"   # ASS colours are &HAABBGGRR
WHITE = "&H00FFFFFF&"
BROWN = "&H0030466B&"
IVORY = "0xEDE6DA"
FONT = "Inter"

ASS_HEADER = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Caption,{FONT} ExtraBold,68,{WHITE},{WHITE},&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,4,3,2,70,70,330,1
Style: Label,{FONT} SemiBold,34,{WHITE},{WHITE},&H00000000,&H78000000,0,0,0,0,100,100,0,0,3,10,0,7,44,44,70,1
Style: Brand,{FONT} ExtraBold,104,{BROWN},{BROWN},&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,0,0,5,60,60,0,1
Style: Tag,{FONT} ExtraBold,60,{GOLD},{GOLD},&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,0,0,5,60,60,0,1
Style: Small,{FONT} Medium,44,{BROWN},{BROWN},&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,5,60,60,0,1
Style: Tiny,{FONT} Medium,34,{BROWN},{BROWN},&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,5,60,60,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def ts(seconds):
    cs = int(round(seconds * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def ass_colour(hex_rgb):
    """'#RRGGBB' -> ASS '&H00BBGGRR&'."""
    r, g, b = hex_rgb[1:3], hex_rgb[3:5], hex_rgb[5:7]
    return f"&H00{b}{g}{r}&".upper()


def caption(text, accent=GOLD):
    """'**accent** words' -> ASS override tags; '\\n' -> line break."""
    text = text.replace("\n", "\\N")
    return re.sub(r"\*\*(.+?)\*\*", lambda m: f"{{\\c{accent}}}{m.group(1)}{{\\c{WHITE}}}", text)


def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"ffmpeg failed:\n{' '.join(cmd)}\n{res.stderr[-2000:]}")


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", str(path)], capture_output=True, text=True)
    return float(out.stdout.strip())


def cleanup_chain(shot):
    """Filters run on the source frames before normalisation."""
    steps = [f"delogo=x={x}:y={y}:w={w}:h={h}" for x, y, w, h in shot.get("erase", [])]
    if shot.get("crop"):
        steps.append("crop={2}:{3}:{0}:{1}".format(*shot["crop"]))
    return "".join(f"{step}," for step in steps)


def fetch(src, dest):
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    if re.match(r"https?://", src):
        with urllib.request.urlopen(src, timeout=120) as res:
            dest.write_bytes(res.read())
    else:
        dest.write_bytes(Path(src).read_bytes())
    return dest


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("plan")
    ap.add_argument("output")
    ap.add_argument("--work", default=None, help="cache folder (default: next to the output)")
    args = ap.parse_args()

    plan = json.loads(Path(args.plan).read_text())
    out = Path(args.output).resolve()
    work = Path(args.work or out.with_suffix("")).resolve()
    work.mkdir(parents=True, exist_ok=True)

    accent = ass_colour(plan["accent"]) if plan.get("accent") else GOLD  # caption keywords
    vf_norm = (f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
               f"fps={FPS},setsar=1,format=yuv420p")
    parts = []

    for i, shot in enumerate(plan["shots"], 1):
        raw = fetch(shot["src"], work / f"shot{i}-raw.mp4")
        length = min(duration(raw), shot.get("max_length", 1e9))
        ass = work / f"shot{i}.ass"
        events = [f"Dialogue: 0,{ts(0)},{ts(length)},Label,,0,0,0,,Personnage IA"]
        if shot.get("caption"):
            margin_v = shot.get("caption_margin_v", 0)  # 0 = the style's default
            events.append(f"Dialogue: 1,{ts(0)},{ts(length)},Caption,,0,0,{margin_v},,{caption(shot['caption'], accent)}")
        ass.write_text(ASS_HEADER + "\n".join(events) + "\n")
        part = work / f"part{i}.mp4"
        enc = ["-c:v", "libx264", "-preset", "medium", "-crf", "18",
               "-c:a", "aac", "-b:a", "192k", "-ar", "48000"]
        ov = shot.get("overlay")
        if ov:
            img = fetch(ov["image"], work / f"shot{i}-overlay{Path(ov['image'].split('?')[0]).suffix}")
            x = f"W-w-{ov.get('margin', 36)}" if ov.get("x", "right") == "right" else str(ov["x"])
            t0, t1 = ov.get("from", 0), min(ov.get("to", length), length)
            graph = (f"[0:v]{cleanup_chain(shot)}{vf_norm}[base];"
                     f"[1:v]scale=-2:{ov.get('height', 820)},format=rgba[ov];"
                     f"[base][ov]overlay=x={x}:y={ov.get('y', 300)}:"
                     f"enable='between(t,{t0},{t1})':eof_action=repeat,ass={ass}[v]")
            run(["ffmpeg", "-y", "-i", str(raw), "-loop", "1", "-i", str(img), "-t", f"{length:.3f}",
                 "-filter_complex", graph, "-map", "[v]", "-map", "0:a",
                 "-af", "aresample=48000,aformat=channel_layouts=stereo", *enc, str(part)])
        else:
            run(["ffmpeg", "-y", "-i", str(raw), "-t", f"{length:.3f}",
                 "-vf", f"{cleanup_chain(shot)}{vf_norm},ass={ass}",
                 "-af", "aresample=48000,aformat=channel_layouts=stereo", *enc, str(part)])
        parts.append(part)

    card = plan.get("end_card")
    if card:
        length = card.get("length", 2.5)
        ass = work / "card.ass"
        lines = [("Brand", -230, card["brand"]), ("Tag", -90, card["tagline"]),
                 ("Small", 160, card["store"]), ("Tiny", 300, card["disclosure"])]
        events = [f"Dialogue: 0,{ts(0)},{ts(length)},{style},,0,0,0,,{{\\pos({W // 2},{H // 2 + dy})}}{text}"
                  for style, dy, text in lines]
        ass.write_text(ASS_HEADER + "\n".join(events) + "\n")
        part = work / "part-card.mp4"
        run(["ffmpeg", "-y",
             "-f", "lavfi", "-i", f"color=c={IVORY}:s={W}x{H}:r={FPS}:d={length}",
             "-f", "lavfi", "-i", f"anullsrc=r=48000:cl=stereo",
             "-t", f"{length}", "-vf", f"ass={ass},fade=t=in:st=0:d=0.4,format=yuv420p",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest", str(part)])
        parts.append(part)

    concat = work / "concat.txt"
    concat.write_text("".join(f"file '{p}'\n" for p in parts))
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
         "-c:v", "copy", "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",  # social-media loudness
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", str(out)])
    print(f"{out}  {duration(out):.2f} s")


if __name__ == "__main__":
    main()
