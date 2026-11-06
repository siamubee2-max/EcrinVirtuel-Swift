#!/usr/bin/env python3
"""Move catalogue images off the dead Supabase project onto the canonical one.

The catalogue rows restored on `vffafgzlsmfecqejoytw` still point at public
storage on `amafgweelzayrjzemdtq`, a project paused behind unpaid invoices.
Every thumbnail in the catalogue is broken, and try-on silently loses its
product reference image (ImageGenerationService.downloadReference returns nil).

For every image URL on the old host in `jewelry.image_url`,
`jewelry.angle_images`, `clothing_catalog.image_url` and `body_parts.image_url`:

  1. read the object, either from the old project (if it has been revived)
     or from a local folder (`--from-dir`, laid out as <bucket>/<path>);
  2. upload it to the SAME bucket and path on the canonical project, creating
     the bucket as public if it does not exist;
  3. check the new public URL answers 200;
  4. only then rewrite the row, swapping the host.

A row is never rewritten unless every one of its images made it across, so
the script can be re-run until nothing is left. Stdlib only.

Usage:
  export NEW_SERVICE_ROLE_KEY=...          # canonical project, service_role
  python3 scripts/migrate-catalog-images.py --dry-run
  python3 scripts/migrate-catalog-images.py
  python3 scripts/migrate-catalog-images.py --from-dir ~/Downloads/old-storage
"""

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

OLD_REF = "amafgweelzayrjzemdtq"
NEW_URL_DEFAULT = "https://vffafgzlsmfecqejoytw.supabase.co"
PUBLIC_PREFIX = "/storage/v1/object/public/"

# table -> columns holding image URLs (text or text[])
TABLES = {
    "jewelry": ["image_url", "angle_images"],
    "clothing_catalog": ["image_url"],
    "body_parts": ["image_url"],
}


class Supabase:
    def __init__(self, base_url: str, key: str):
        self.base = base_url.rstrip("/")
        self.key = key

    def request(self, method, path, body=None, headers=None, raw=False):
        req = urllib.request.Request(self.base + path, method=method, data=body)
        req.add_header("apikey", self.key)
        req.add_header("Authorization", f"Bearer {self.key}")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        with urllib.request.urlopen(req, timeout=60) as res:
            data = res.read()
            return data if raw else (json.loads(data) if data else None)

    def rows(self, table, columns):
        select = ",".join(["id", *columns])
        return self.request("GET", f"/rest/v1/{table}?select={select}")

    def patch(self, table, row_id, values):
        self.request(
            "PATCH",
            f"/rest/v1/{table}?id=eq.{urllib.parse.quote(str(row_id))}",
            body=json.dumps(values).encode(),
            headers={"Content-Type": "application/json", "Prefer": "return=minimal"},
        )

    def ensure_public_bucket(self, bucket, created):
        if bucket in created:
            return
        try:
            self.request("GET", f"/storage/v1/bucket/{bucket}")
        except urllib.error.HTTPError as e:
            if e.code not in (400, 404):
                raise
            self.request(
                "POST",
                "/storage/v1/bucket",
                body=json.dumps({"id": bucket, "name": bucket, "public": True}).encode(),
                headers={"Content-Type": "application/json"},
            )
            print(f"  + created public bucket '{bucket}'")
        created.add(bucket)

    def upload(self, bucket, path, data):
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        self.request(
            "POST",
            f"/storage/v1/object/{bucket}/{urllib.parse.quote(path)}",
            body=data,
            headers={"Content-Type": ctype, "x-upsert": "true", "Cache-Control": "max-age=31536000"},
        )


def split_old_url(url):
    """Return (bucket, path) for a public URL on the old project, else None."""
    if not isinstance(url, str) or f"{OLD_REF}.supabase.co" not in url:
        return None
    parsed = urllib.parse.urlparse(url)
    if not parsed.path.startswith(PUBLIC_PREFIX):
        return None
    bucket, _, path = parsed.path[len(PUBLIC_PREFIX):].partition("/")
    return (bucket, urllib.parse.unquote(path)) if bucket and path else None


def new_url_for(url, new_base):
    parsed = urllib.parse.urlparse(url)
    new = urllib.parse.urlparse(new_base)
    return urllib.parse.urlunparse(parsed._replace(scheme=new.scheme, netloc=new.netloc))


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as res:
        return res.read()


def is_live(url):
    try:
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=30) as res:
            return res.status == 200
    except urllib.error.URLError:
        return False


def read_source(url, bucket, path, from_dir):
    if from_dir:
        local = Path(from_dir).expanduser() / bucket / path
        return local.read_bytes() if local.is_file() else None
    try:
        return fetch(url)
    except urllib.error.URLError:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="list what would move, change nothing")
    ap.add_argument("--from-dir", help="read objects from <dir>/<bucket>/<path> instead of the old project")
    ap.add_argument("--new-url", default=os.environ.get("NEW_SUPABASE_URL", NEW_URL_DEFAULT))
    args = ap.parse_args()

    key = os.environ.get("NEW_SERVICE_ROLE_KEY")
    if not key:
        sys.exit("NEW_SERVICE_ROLE_KEY is not set (canonical project → Settings → API → service_role).")
    if OLD_REF in args.new_url:
        sys.exit("--new-url points at the dead project.")

    sb = Supabase(args.new_url, key)
    buckets_ready = set()
    migrated = done_rows = 0
    missing = []

    for table, columns in TABLES.items():
        rows = sb.rows(table, columns)
        stale = [r for r in rows if any(split_old_url(u) for c in columns for u in _urls(r.get(c)))]
        print(f"{table}: {len(stale)}/{len(rows)} rows reference {OLD_REF}")

        for row in stale:
            updates, row_ok = {}, True
            for col in columns:
                value = row.get(col)
                urls = _urls(value)
                rewritten = []
                for url in urls:
                    parts = split_old_url(url)
                    if not parts:
                        rewritten.append(url)
                        continue
                    bucket, path = parts
                    target = new_url_for(url, args.new_url)
                    if args.dry_run:
                        print(f"  would copy {bucket}/{path}")
                        rewritten.append(target)
                        continue
                    if not is_live(target):
                        data = read_source(url, bucket, path, args.from_dir)
                        if data is None:
                            missing.append(f"{bucket}/{path}")
                            row_ok = False
                            break
                        sb.ensure_public_bucket(bucket, buckets_ready)
                        sb.upload(bucket, path, data)
                        if not is_live(target):
                            missing.append(f"{bucket}/{path} (uploaded but not served)")
                            row_ok = False
                            break
                        migrated += 1
                    rewritten.append(target)
                if not row_ok:
                    break
                updates[col] = rewritten if isinstance(value, list) else (rewritten[0] if rewritten else value)

            if row_ok and not args.dry_run:
                sb.patch(table, row["id"], updates)
                done_rows += 1

    print()
    if args.dry_run:
        print("Dry run — nothing changed.")
    else:
        print(f"Objects copied: {migrated} · rows rewritten: {done_rows}")
    if missing:
        print(f"{len(missing)} object(s) unavailable — their rows were left untouched:")
        for m in sorted(set(missing)):
            print(f"  - {m}")
        sys.exit(1)


def _urls(value):
    if value is None:
        return []
    return list(value) if isinstance(value, list) else [value]


if __name__ == "__main__":
    main()
