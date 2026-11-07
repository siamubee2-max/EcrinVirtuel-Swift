#!/usr/bin/env python3
"""Daily price check: which provider is cheapest for the models Lou's content uses.

Sources (all public, no key printed or stored by this script):
  - fal.ai       : the model page ("Your request will cost $X per image/second")
  - kie.ai       : the pricing table (credits and USD; 1 credit = $0.005)
  - openrouter.ai: GET /api/v1/videos/models and /api/v1/models (pricing field).
                   If the session proxy injects a key, it is used by the proxy, never by this script.
  - higgsfield.ai: prices are in credits and rendered in the browser, so they CANNOT be read here.
                   The scheduled task asks the Higgsfield connector (models_explore) instead.

Usage:  python3 scripts/provider-prices.py [--out docs/marketing/prix-fournisseurs]
Writes <out>/YYYY-MM-DD.md and prints it. Prices marked "dès" are the lowest tier the
provider advertises (shortest/cheapest settings): check the exact settings before comparing.
"""

import argparse
import datetime
import json
import re
import urllib.request
from pathlib import Path

CREDIT_USD = 0.005  # kie.ai: 10.1 credits = $0.0505

# What we actually use. fal/kie/openrouter keys are matched against the provider listings.
USE_CASES = [
    {"name": "Image de Lou (nano-banana-2 edit, 2K)", "unit": "image",
     "fal": "fal-ai/nano-banana-2/edit", "kie": "Google nano banana 2",
     "openrouter_image": r"(nano.?banana|gemini.*flash.*image)"},
    {"name": "Synchro labiale (Kling AI Avatar standard)", "unit": "seconde",
     "fal": "fal-ai/kling-video/ai-avatar/v2/standard", "kie": "Kling AI Avatar",
     "openrouter_video": "heygen/avatar-iv",
     "note": "OpenRouter n'a pas Kling Avatar : HeyGen Avatar IV est l'équivalent le plus proche (pas le même rendu)."},
    {"name": "Vidéo Seedance 2.5", "unit": "seconde",
     "fal": "bytedance/seedance-2.5/text-to-video", "kie": "bytedance/seedance-2-5",
     "openrouter_video": "bytedance/seedance-2.5",
     "note": "Kie affiche son palier « dès » (résolution la plus basse probable) alors que fal et OpenRouter sont en 720p : confirme la résolution de Kie avant de conclure."},
]


def get(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (price-check)"})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        return res.read().decode("utf-8", "ignore")


def fal_price(endpoint):
    """Returns ({"usd", "per", "note", "tok_usd"}, error). Tries the 3 ways fal words its prices."""
    try:
        html = get(f"https://fal.ai/models/{endpoint}")
    except Exception as exc:  # noqa: BLE001 - report, never crash the whole report
        return None, f"page fal illisible ({exc.__class__.__name__})"
    tok = re.search(r"\*\*\$([\d.]+)\*\* per 1,000 tokens", html)
    tok_usd = float(tok.group(1)) / 1000 if tok else None
    m = re.search(r"for 720p, you will be charged roughly \*\*\$([\d.]+)\*\* per second", html)
    if m:
        return {"usd": float(m.group(1)), "per": "second", "note": "720p", "tok_usd": tok_usd}, None
    m = re.search(r"cost \*\*\$([\d.]+)\*\* per (image|second|video)\b", html)
    if m:
        return {"usd": float(m.group(1)), "per": m.group(2), "note": "", "tok_usd": tok_usd}, None
    m = re.search(r"\$([\d.]+) per second", html)
    if m:
        return {"usd": float(m.group(1)), "per": "second", "note": "", "tok_usd": tok_usd}, None
    return None, "prix introuvable sur la page"


def kie_table():
    html = get("https://kie.ai/pricing")
    rows = {}
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", html, re.S):
        cells = [re.sub(r"<[^>]+>", "", c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.S)]
        if len(cells) >= 2 and "$" in cells[1]:
            rows[cells[0].lower()] = cells[1]
    return rows


def kie_price(table, name):
    text = table.get(name.lower())
    if not text:
        return None, "absent du tableau Kie"
    m = re.search(r"\$([\d.]+) per (\w+)", text)
    return ({"usd": float(m.group(1)), "per": m.group(2), "from": text.startswith("from")}, None) if m else (None, text)


def openrouter_discount(model_id):
    """OpenRouter shows promotions (e.g. "Price 50% off from $0.01 /second") on the model page only."""
    try:
        html = get(f"https://openrouter.ai/{model_id}")
    except Exception:  # noqa: BLE001
        return 0.0
    text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", re.sub(r"<script.*?</script>|<style.*?</style>", " ", html, flags=re.S)))
    m = re.search(r"Price (\d+)% off", text)
    return int(m.group(1)) / 100 if m else 0.0


def openrouter_video(models, mid):
    for m in models:
        if m["id"] == mid:
            return m.get("pricing_skus") or m.get("pricing") or {}
    return None


def run():
    kie, kie_err = {}, None
    try:
        kie = kie_table()
    except Exception as exc:  # noqa: BLE001
        kie_err = f"tableau Kie illisible ({exc.__class__.__name__})"
    try:
        or_video = json.loads(get("https://openrouter.ai/api/v1/videos/models"))["data"]
        or_all = json.loads(get("https://openrouter.ai/api/v1/models"))["data"]
    except Exception:  # noqa: BLE001
        or_video, or_all = [], []

    lines = []
    for uc in USE_CASES:
        rows = []  # (provider, usd per unit or None, comment)
        usd, err = fal_price(uc["fal"])
        fal_ok = bool(usd) and usd["per"].startswith(uc["unit"][:3])
        rows.append(("fal.ai", usd["usd"] if fal_ok else None,
                     f"{usd['usd']} $ / {usd['per']}{' (' + usd['note'] + ')' if usd['note'] else ''}" if usd else err))
        k, err = kie_price(kie, uc["kie"]) if not kie_err else (None, kie_err)
        rows.append(("kie.ai", k["usd"] if k else None,
                     f"{'dès ' if k and k['from'] else ''}{k['usd']} $ / {k['per']} (≈ {round(k['usd'] / CREDIT_USD, 1)} crédits)" if k else err))
        if "openrouter_video" in uc:
            p = openrouter_video(or_video, uc["openrouter_video"])
            per_s = next((float(v) for key, v in (p or {}).items() if key in ("duration_seconds", "duration_seconds_720p")), None)
            if p is None:
                rows.append(("openrouter.ai", None, f"{uc['openrouter_video']} absent"))
            elif per_s is not None:
                d = openrouter_discount(uc["openrouter_video"])
                net = per_s * (1 - d)
                rows.append(("openrouter.ai", net, f"{net:.4f} $ / seconde ({uc['openrouter_video']}"
                             + (f", remise {int(d * 100)} % déjà appliquée" if d else ", pas de remise") + ")"))
            elif "video_tokens" in p and usd and usd.get("tok_usd"):
                est = usd["usd"] * float(p["video_tokens"]) / usd["tok_usd"]  # fal tokens/s x OpenRouter $/token
                rows.append(("openrouter.ai", est, f"≈ {est:.3f} $ / seconde (720p, ESTIMATION : {p['video_tokens']} $/token x tokens/s déduits de fal)"))
            else:
                rows.append(("openrouter.ai", None, f"tarif non par seconde : {json.dumps(p)[:140]}"))
        else:
            hits = [m for m in or_all if re.search(uc["openrouter_image"], m["id"], re.I)
                    and "image" in (m.get("architecture", {}).get("output_modalities") or [])]
            hit = hits[0] if hits else None
            img = float((hit or {}).get("pricing", {}).get("image", 0) or 0)
            rows.append(("openrouter.ai", img or None,
                         f"{img} $ / image ({hit['id']})" if img else (f"{hit['id']} : pas de tarif par image" if hit else "aucun modèle équivalent")))
        rows.append(("higgsfield.ai", None, "à lire via le connecteur Higgsfield (crédits), non lisible ici"))
        priced = [r for r in rows if r[1] is not None]
        best = min(priced, key=lambda r: r[1])[0] if priced else "indéterminé"
        lines.append(f"### {uc['name']}\n")
        lines.append("| Fournisseur | Prix relevé |\n|---|---|")
        lines += [f"| {p} | {c} |" for p, _, c in rows]
        lines.append(f"\n**Moins cher d'après les prix lisibles : {best}** (réglages à confirmer avant de lancer)" + (f"  \n_{uc['note']}_" if uc.get("note") else "") + "\n")
    lines.append(_heygen_video_section(or_video))
    return "\n".join(lines)


def _heygen_video_section(or_video):
    """HeyGen Video is promoted at 50 % on OpenRouter (page only; the API lists the full price).
    The long-duration and some other SKUs are exempt from the discount (isDiscountExempt)."""
    mid = "heygen/heygen-video-1"
    p = openrouter_video(or_video, mid)
    if not p:
        return ""
    d = openrouter_discount(mid)
    out = [f"### Promotion OpenRouter : {mid} (vidéo générale, sans synchro labiale)\n",
           f"Remise affichée sur la page : {int(d * 100)} %. Prix par seconde (plein tarif → remisé) :\n",
           "| Résolution | Plein tarif | Remisé |", "|---|---|---|"]
    for res in ("480p", "768p", "1080p", "2K"):
        v = p.get(f"duration_seconds_{res.lower()}")
        if v:
            out.append(f"| {res} | {float(v):.3f} $ | {float(v) * (1 - d):.3f} $ |")
    out.append("\n_Les tarifs « longue durée » et « références » ne sont pas tous remisés (page : isDiscountExempt). "
               "Ce modèle n'a pas d'étape de synchro labiale : il ne remplace pas Kling Avatar. "
               "Remise lue sur la page web, à confirmer sur la facture du premier essai._\n")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="docs/marketing/prix-fournisseurs")
    args = ap.parse_args()
    today = datetime.date.today().isoformat()
    body = (f"# Prix des fournisseurs, {today}\n\n"
            "Relevé automatique (`scripts/provider-prices.py`). « dès » = palier le plus bas affiché par le fournisseur.\n\n"
            + run())
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / f"{today}.md").write_text(body)
    print(body)


if __name__ == "__main__":
    main()
