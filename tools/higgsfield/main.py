#!/usr/bin/env python3
"""Generate a video with Seedance 2.5 through the Higgsfield API.

Credentials: HF_KEY="key-id:key-secret", read from the environment or from
.env.local next to this file. The key is never printed, logged or committed
(.env.local is in .gitignore). Create the key in the Higgsfield console.

Usage:
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python main.py

Note: running this makes a billable generation request.

`subscribe` does not raise when a request fails, is moderated or is cancelled:
it waits for the final state and returns the response as is. So this script
records the final state itself and only reports success for `Completed` with a
video URL in the result.
"""

import os
import sys
from pathlib import Path

import higgsfield_client
from dotenv import load_dotenv

MODEL = "bytedance/seedance-2.5/text-to-video"
ARGUMENTS = {
    "prompt": "A cinematic scene at sunset",
    "duration": 5,
    "resolution": "720p",
    "aspect_ratio": "16:9",
}


def load_credentials() -> None:
    """Load HF_KEY from .env.local (next to this file) and check its shape, without echoing it."""
    load_dotenv(Path(__file__).with_name(".env.local"))
    key = os.environ.get("HF_KEY", "").strip()
    key_id, _, secret = key.partition(":")
    if not (key_id and secret):
        sys.exit(
            "HF_KEY is missing or malformed. Put HF_KEY=key-id:key-secret in "
            "tools/higgsfield/.env.local (never in a committed file)."
        )


def main() -> int:
    load_credentials()

    final = {}  # last status seen while polling

    def on_enqueue(request_id: str) -> None:
        print(f"Submitted, request id: {request_id}", flush=True)

    def on_queue_update(status) -> None:
        final["status"] = status
        print(f"  status: {type(status).__name__}", flush=True)

    try:
        result = higgsfield_client.subscribe(
            MODEL,
            arguments=ARGUMENTS,
            on_enqueue=on_enqueue,
            on_queue_update=on_queue_update,
        )
    except higgsfield_client.CredentialsMissedError as exc:
        print(f"Credentials error: {exc}", file=sys.stderr)
        return 2
    except higgsfield_client.HiggsfieldClientError as exc:
        # HTTP errors: 401 bad key, 402 or similar when the balance is too low, 4xx on bad input, 5xx.
        print(f"The Higgsfield API refused the request: {exc}", file=sys.stderr)
        return 1

    status = final.get("status")
    if isinstance(status, higgsfield_client.NSFW):
        print("Request was moderated (NSFW). No video was produced.", file=sys.stderr)
        return 1
    if isinstance(status, higgsfield_client.Cancelled):
        print("Request was cancelled. No video was produced.", file=sys.stderr)
        return 1
    if isinstance(status, higgsfield_client.Failed):
        print("Request failed. No video was produced.", file=sys.stderr)
        return 1
    if not isinstance(status, higgsfield_client.Completed):
        print(f"Unexpected final state: {status!r}. Not treating it as a success.", file=sys.stderr)
        return 1

    video = result.get("video") if isinstance(result, dict) else None
    url = video.get("url") if isinstance(video, dict) else None
    if not url:
        print("Completed, but the response has no video URL. Not treating it as a success.", file=sys.stderr)
        return 1

    print(f"Video URL: {url}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
