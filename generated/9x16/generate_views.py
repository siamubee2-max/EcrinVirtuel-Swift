#!/usr/bin/env python3
"""Generate 9:16 fashion views via Kie.ai market API."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".claude/skills/kieforge/scripts"))
from kie_client import post, poll_task  # noqa: E402

OUT = Path(__file__).resolve().parent
MODEL = "gpt-image-2-text-to-image"

VIEWS = {
    "face": (
        "Professional fashion catalog photo, vertical 9:16 full body. Woman mid-20s, "
        "long wavy dark brown hair, warm tan skin, short black mini dress thin spaghetti "
        "straps sweetheart neckline fitted bodice flared A-line skirt, black strappy "
        "stiletto heels. Front view facing camera, relaxed hand on hip. Clean off-white "
        "studio background, soft diffused lighting, photorealistic high-end e-commerce, "
        "no text no logo no watermark."
    ),
    "back": (
        "Professional fashion catalog photo, vertical 9:16 full body. Same woman and outfit: "
        "short black mini dress from behind, thin straps, low open back, skirt with subtle "
        "ruching and draped asymmetric hem. Black strappy heels. Back view standing straight, "
        "hair over shoulders. Off-white studio background, soft lighting, photorealistic, "
        "no text no watermark."
    ),
    "three-quarter": (
        "Professional fashion catalog photo, vertical 9:16 full body. Woman in short black "
        "spaghetti-strap mini dress and black strappy heels, three-quarter front angle, "
        "elegant pose hand on hip. Long wavy dark brown hair, warm tan skin. Off-white "
        "studio background, photorealistic e-commerce, no text."
    ),
    "hero": (
        "Virtual try-on hero shot, vertical 9:16 full body portrait. Woman wearing chic black "
        "mini dress and black strappy heels, confident fashion pose center frame, long wavy "
        "dark hair. Premium off-white studio backdrop like luxury fashion app, even lighting, "
        "photorealistic magazine quality, no UI no text no watermark."
    ),
}


def generate_one(name: str, prompt: str) -> dict:
    data = post(
        "/api/v1/jobs/createTask",
        {
            "model": MODEL,
            "input": {"prompt": prompt, "aspect_ratio": "9:16", "nVariants": 1},
        },
    )
    task_id = data.get("taskId") or data.get("task_id") or data.get("id")
    result = poll_task(task_id)
    url = result.get("url") or (result.get("_all_urls") or [None])[0]
    if not url:
        raise RuntimeError(f"No URL for {name}: {result}")
    dest = OUT / f"{name}.png"
    proc = subprocess.run(
        ["curl", "-fsSL", "-o", str(dest), url],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Download failed for {name}: {proc.stderr.strip()}")
    return {"name": name, "path": str(dest), "url": url, "task_id": task_id}


def main() -> int:
    results = []
    errors = []
    for name, prompt in VIEWS.items():
        try:
            results.append(generate_one(name, prompt))
            print(f"OK {name}", flush=True)
        except Exception as exc:
            errors.append(f"{name}: {exc}")
            print(f"FAIL {name}: {exc}", file=sys.stderr, flush=True)

    if errors:
        print("Errors:\n" + "\n".join(errors), file=sys.stderr)
        if not results:
            return 1

    manifest = OUT / "manifest.json"
    manifest.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
