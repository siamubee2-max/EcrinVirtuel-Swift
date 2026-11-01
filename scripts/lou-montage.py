#!/usr/bin/env python3
"""Assemble one of Lou's videos from its lip-synced shots.

Input is a JSON plan: an ordered list of shots, each with the clip URL (or a
local path) and its burned-in caption, plus the end card text. The script:

  1. downloads every clip (cached in --work);
  2. normalises each one to 1080x1920, 25 fps, AAC 48 kHz stereo;
  3. burns the caption (keywords between ** ** in gold #C9A24B), the
     "Personnage IA" label (top left, whole video) via libass;
  4. builds the ivory end card with the AI disclosure;
  5. concatenates everything into a single H.264 MP4.

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


def caption(text):
    """'**gold** words' -> ASS override tags; '\\n' -> line break."""
    text = text.replace("\n", "\\N")
    return re.sub(r"\*\*(.+?)\*\*", lambda m: f"{{\\c{GOLD}}}{m.group(1)}{{\\c{WHITE}}}", text)


def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"ffmpeg failed:\n{' '.join(cmd)}\n{res.stderr[-2000:]}")


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", str(path)], capture_output=True, text=True)
    return float(out.stdout.strip())


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

    vf_norm = (f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
               f"fps={FPS},setsar=1,format=yuv420p")
    parts = []

    for i, shot in enumerate(plan["shots"], 1):
        raw = fetch(shot["src"], work / f"shot{i}-raw.mp4")
        length = min(duration(raw), shot.get("max_length", 1e9))
        ass = work / f"shot{i}.ass"
        events = [f"Dialogue: 0,{ts(0)},{ts(length)},Label,,0,0,0,,Personnage IA"]
        if shot.get("caption"):
            events.append(f"Dialogue: 1,{ts(0)},{ts(length)},Caption,,0,0,0,,{caption(shot['caption'])}")
        ass.write_text(ASS_HEADER + "\n".join(events) + "\n")
        part = work / f"part{i}.mp4"
        run(["ffmpeg", "-y", "-i", str(raw), "-t", f"{length:.3f}",
             "-vf", f"{vf_norm},ass={ass}",
             "-af", "aresample=48000,aformat=channel_layouts=stereo",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-c:a", "aac", "-b:a", "192k", "-ar", "48000", str(part)])
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
         "-c", "copy", "-movflags", "+faststart", str(out)])
    print(f"{out}  {duration(out):.2f} s")


if __name__ == "__main__":
    main()
