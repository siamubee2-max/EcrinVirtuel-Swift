#!/usr/bin/env python3
"""Cut a ~7-second punchline video for Lou: hook, punch, call to action.

The plan is a JSON file:

  {
    "hook": "POV : tu oses ENFIN le rouge",      # big native-style text, top
    "hook_until": 2.2,                           # seconds the hook stays on
    "segments": [                                # played back to back
      {"clip": "<url or path>", "start": 0, "length": 1.9, "caption": "Le rouge."},
      {"image": "<url or path>", "length": 1.3, "zoom": true}
      # a clip may also take "crop": [x, y, w, h] in source pixels
    ],
    "cta": {
      "length": 2.3,
      "background": "<url or path of a still>",  # blurred and darkened
      "lines": ["Ta couleur interdite ?", "**Essaie-la gratuitement**", "L'Écrin Virtuel · App Store"]
    }
  }

Captions and CTA lines take **keywords** in gold. Output: 1080x1920, 25 fps,
H.264 + AAC, loudness-normalised to -14 LUFS. Needs ffmpeg with libass.

Usage: python3 scripts/lou-punchline.py plan.json out.mp4 [--work DIR]
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from hashlib import sha1
from pathlib import Path

W, H, FPS = 1080, 1920, 25
GOLD = "&H004BA2C9&"
WHITE = "&H00FFFFFF&"
BLACK = "&H00000000&"

ASS_HEADER = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Hook,Inter ExtraBold,66,{BLACK},{BLACK},{WHITE},{WHITE},1,0,0,0,100,100,0,0,3,14,0,8,90,90,300,1
Style: Caption,Inter ExtraBold,62,{WHITE},{WHITE},&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,4,3,2,80,80,360,1
Style: CTA,Inter ExtraBold,76,{WHITE},{WHITE},&H00000000,&H80000000,1,0,0,0,100,100,0,0,1,3,2,5,80,80,0,1
Style: CTASmall,Inter SemiBold,46,{WHITE},{WHITE},&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,2,5,80,80,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def ts(s):
    cs = int(round(s * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def ass_text(text, base=WHITE):
    text = text.replace("\n", "\\N")
    return re.sub(r"\*\*(.+?)\*\*", lambda m: f"{{\\c{GOLD}}}{m.group(1)}{{\\c{base}}}", text)


def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"ffmpeg failed:\n{' '.join(cmd)}\n{res.stderr[-2000:]}")


def fetch(src, work):
    if not re.match(r"https?://", src):
        return Path(src)
    dest = work / (sha1(src.encode()).hexdigest()[:16] + Path(src.split("?")[0]).suffix)
    if not dest.exists():
        with urllib.request.urlopen(src, timeout=120) as res:
            dest.write_bytes(res.read())
    return dest


ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
       "-c:a", "aac", "-b:a", "192k", "-ar", "48000"]
NORM = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},fps={FPS},setsar=1"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("plan")
    ap.add_argument("output")
    ap.add_argument("--work")
    args = ap.parse_args()

    plan = json.loads(Path(args.plan).read_text())
    out = Path(args.output).resolve()
    work = Path(args.work or out.with_suffix("")).resolve()
    work.mkdir(parents=True, exist_ok=True)

    parts, t = [], 0.0
    for i, seg in enumerate(plan["segments"]):
        part = work / f"seg{i}.mp4"
        length = seg["length"]
        if "clip" in seg:
            src = fetch(seg["clip"], work)
            crop = "crop={2}:{3}:{0}:{1},".format(*seg["crop"]) if seg.get("crop") else ""  # cut baked-in text
            run(["ffmpeg", "-y", "-ss", str(seg.get("start", 0)), "-i", str(src), "-t", f"{length}",
                 "-vf", crop + NORM, "-af", "aresample=48000,aformat=channel_layouts=stereo", *ENC, str(part)])
        else:  # still image, slow push-in
            src = fetch(seg["image"], work)
            frames = int(length * FPS)
            zoom = (f"zoompan=z='1+0.08*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                    f":d={frames}:s={W}x{H}:fps={FPS}" if seg.get("zoom", True) else f"fps={FPS}")
            run(["ffmpeg", "-y", "-loop", "1", "-i", str(src), "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                 "-t", f"{length}", "-vf", f"scale={W * 2}:{H * 2}:force_original_aspect_ratio=increase,"
                 f"crop={W * 2}:{H * 2},{zoom},setsar=1", *ENC, "-shortest", str(part)])
        parts.append((part, t, length, seg.get("caption")))
        t += length

    cta = plan["cta"]
    bg = fetch(cta["background"], work)
    cta_part = work / "cta.mp4"
    run(["ffmpeg", "-y", "-loop", "1", "-i", str(bg), "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
         "-t", f"{cta['length']}", "-vf", f"{NORM},boxblur=24:2,eq=brightness=-0.22:saturation=0.8",
         *ENC, "-shortest", str(cta_part)])
    parts.append((cta_part, t, cta["length"], None))
    total = t + cta["length"]

    concat = work / "concat.txt"
    concat.write_text("".join(f"file '{p}'\n" for p, *_ in parts))
    raw = work / "raw.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", str(raw)])

    events = [f"Dialogue: 2,{ts(0)},{ts(plan.get('hook_until', 2.2))},Hook,,0,0,0,,{ass_text(plan['hook'], BLACK)}"]
    for _, start, length, caption in parts:
        if caption:
            events.append(f"Dialogue: 1,{ts(start)},{ts(start + length)},Caption,,0,0,0,,{ass_text(caption)}")
    lines = cta["lines"]
    y0 = H / 2 - (len(lines) - 1) * 70
    for k, line in enumerate(lines):
        style = "CTASmall" if k == len(lines) - 1 else "CTA"
        pop = "{\\fscx80\\fscy80\\t(0,180,\\fscx100\\fscy100)}"  # small pop-in
        events.append(f"Dialogue: 3,{ts(t + 0.08 * k)},{ts(total)},{style},,0,0,0,,"
                      f"{{\\pos({W // 2},{int(y0 + k * 140)})}}{pop}{ass_text(line)}")
    ass = work / "overlay.ass"
    ass.write_text(ASS_HEADER + "\n".join(events) + "\n")

    run(["ffmpeg", "-y", "-i", str(raw), "-vf", f"ass={ass}", "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",
         *ENC, "-movflags", "+faststart", str(out)])
    print(f"{out}  {total:.2f} s")


if __name__ == "__main__":
    main()
