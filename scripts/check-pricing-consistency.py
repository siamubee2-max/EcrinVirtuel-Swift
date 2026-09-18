#!/usr/bin/env python3
"""Cross-check the pricing grid across every place that states it.

The paywall has four sources of truth for "what does this product cost and
what does the buyer get":

  1. the app's own tables — CreditsPack.all and PaywallView's allPlans;
  2. the server, which actually grants the credits — credit-generations'
     VALID_PACKS (consumables) and revenuecat-webhook's planForProduct
     (subscriptions);
  3. EcrinVirtuel.storekit, the local sandbox the simulator runs against;
  4. App Store Connect, which is what the buyer reads on Apple's
     confirmation sheet — NOT checkable from here.

Sources 1-3 live in this repo, so drift between them is catchable. It has
happened: a pricing rework moved the app and the server to Spark 10 /
Éclat 40 / Diamant 140 while the sandbox still said Éclat 70 + 5 offerts at
16,99 €, and nothing failed — local testing simply showed prices and counts
nobody would ever be charged or granted.

Source 4 stays a human's job. This script cannot see App Store Connect; when
1-3 agree it prints the grid so it can be compared against ASC by eye.

Exit status: 0 when consistent, 1 on any mismatch.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

CREDITS_PACK = ROOT / "Sources/Features/Credits/CreditsPack.swift"
PAYWALL_VIEW = ROOT / "Sources/Features/Paywall/PaywallView.swift"
CREDIT_FN = ROOT / "supabase/functions/credit-generations/index.ts"
WEBHOOK_FN = ROOT / "supabase/functions/revenuecat-webhook/index.ts"
STOREKIT = ROOT / "EcrinVirtuel.storekit"

problems: list[str] = []


def fail(msg: str) -> None:
    problems.append(msg)


def read(path: pathlib.Path) -> str:
    if not path.exists():
        fail(f"fichier introuvable : {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


# ── 1. Packs de crédits : app vs serveur ────────────────────────────────────

def app_packs(src: str) -> dict[str, dict]:
    """CreditsPack.all -> {product_id: {count, reference_price}}"""
    packs = {}
    # Chaque entrée : id: "...", label: "...", count: N, price: "...",
    # referencePrice: N.NN
    for m in re.finditer(
        r'id:\s*"([^"]+)".*?count:\s*(\d+).*?referencePrice:\s*([\d.]+)',
        src,
        re.S,
    ):
        packs[m.group(1)] = {
            "count": int(m.group(2)),
            "price": float(m.group(3)),
        }
    return packs


def server_packs(src: str) -> dict[str, int]:
    """VALID_PACKS -> {product_id: credits}"""
    block = re.search(r"VALID_PACKS[^=]*=\s*\{(.*?)\n\}", src, re.S)
    if not block:
        fail("VALID_PACKS introuvable dans credit-generations/index.ts")
        return {}
    return {
        m.group(1): int(m.group(2))
        for m in re.finditer(r'"([^"]+)":\s*(\d+)', block.group(1))
    }


# ── 2. Abonnements : app vs webhook ─────────────────────────────────────────

def app_plans(src: str) -> dict[str, dict]:
    """allPlans -> {rc_product_id: {credits, price}}"""
    ids = dict(
        re.findall(r'static let (\w+)\s*=\s*"([^"]+)"', src)
    )  # PaywallProductID
    plans = {}
    for m in re.finditer(
        r'price:\s*"([^"]+)".*?rcIdentifier:\s*PaywallProductID\.(\w+).*?'
        r"creditsPerMonth:\s*(\d+)",
        src,
        re.S,
    ):
        product = ids.get(m.group(2))
        if not product:
            fail(f"PaywallProductID.{m.group(2)} non résolu")
            continue
        price = float(m.group(1).replace("€", "").replace(",", ".").strip())
        plans[product] = {"credits": int(m.group(3)), "price": price}
    return plans


def webhook_credits(src: str, product_id: str) -> int | None:
    """Rejoue planForProduct : premier mot-clé rencontré qui matche."""
    rules = re.findall(
        r'p\.includes\("(\w+)"\)(?:[^\n]*?\|\|\s*p\.includes\("(\w+)"\))?'
        r'(?:[^\n]*?\|\|\s*p\.includes\("(\w+)"\))?[^\n]*?\n?\s*'
        r"return\s*\{[^}]*credits:\s*(\d+)",
        src,
    )
    p = product_id.lower()
    for a, b, c, credits in rules:
        if any(kw and kw in p for kw in (a, b, c)):
            return int(credits)
    return None


# ── 3. Sandbox StoreKit ─────────────────────────────────────────────────────

def storekit_prices(path: pathlib.Path) -> dict[str, float]:
    if not path.exists():
        fail(f"fichier introuvable : {path.name}")
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    prices = {
        p["productID"]: float(p["displayPrice"]) for p in data.get("products", [])
    }
    for group in data.get("subscriptionGroups", []):
        for sub in group.get("subscriptions", []):
            prices[sub["productID"]] = float(sub["displayPrice"])
    return prices


# ── Exécution ───────────────────────────────────────────────────────────────

pack_src = read(CREDITS_PACK)
plan_src = read(PAYWALL_VIEW)
credit_src = read(CREDIT_FN)
hook_src = read(WEBHOOK_FN)
sk_prices = storekit_prices(STOREKIT)

packs = app_packs(pack_src)
valid = server_packs(credit_src)
plans = app_plans(plan_src)

if not packs:
    fail("aucun pack lu dans CreditsPack.swift — le format a changé ?")
if not plans:
    fail("aucun plan lu dans PaywallView.swift — le format a changé ?")

# Packs vendus par l'app : le serveur DOIT créditer exactement ce nombre.
for pid, pack in sorted(packs.items()):
    granted = valid.get(pid)
    if granted is None:
        fail(
            f"{pid} : vendu par l'app ({pack['count']} crédits) mais absent de "
            f"VALID_PACKS — l'achat serait encaissé puis refusé (unknown_product)"
        )
    elif granted != pack["count"]:
        fail(
            f"{pid} : l'app annonce {pack['count']} crédits, le serveur en "
            f"crédite {granted}"
        )
    sk = sk_prices.get(pid)
    if sk is not None and abs(sk - pack["price"]) > 0.001:
        fail(
            f"{pid} : prix de repli {pack['price']:.2f} € mais "
            f"{sk:.2f} € dans EcrinVirtuel.storekit"
        )
    elif sk is None:
        fail(f"{pid} : vendu par l'app mais absent de EcrinVirtuel.storekit")

# Abonnements affichés : le webhook DOIT accorder le même nombre de crédits.
for pid, plan in sorted(plans.items()):
    granted = webhook_credits(hook_src, pid)
    if granted is None:
        fail(
            f"{pid} : affiché par le paywall mais aucune règle ne le reconnaît "
            f"dans revenuecat-webhook — renouvellement sans crédits"
        )
    elif granted != plan["credits"]:
        fail(
            f"{pid} : le paywall annonce {plan['credits']} crédits/mois, le "
            f"webhook en accorde {granted}"
        )
    sk = sk_prices.get(pid)
    if sk is not None and abs(sk - plan["price"]) > 0.001:
        fail(
            f"{pid} : prix de repli {plan['price']:.2f} € mais "
            f"{sk:.2f} € dans EcrinVirtuel.storekit"
        )
    elif sk is None:
        fail(f"{pid} : affiché par le paywall mais absent de EcrinVirtuel.storekit")

if problems:
    print("Incohérences de tarification :\n", file=sys.stderr)
    for p in problems:
        print(f"  ✗ {p}", file=sys.stderr)
    print(
        "\nL'app, le serveur et le sandbox StoreKit doivent annoncer la même "
        "grille.\nCorrige la source fautive — ne fais pas diverger davantage.",
        file=sys.stderr,
    )
    sys.exit(1)

print("Grille cohérente entre l'app, le serveur et le sandbox StoreKit.\n")
print(f"  {'produit':28} {'prix':>8}  crédits")
for pid, pack in sorted(packs.items()):
    print(f"  {pid:28} {pack['price']:>7.2f} €  {pack['count']:>4} (pack)")
for pid, plan in sorted(plans.items()):
    print(f"  {pid:28} {plan['price']:>7.2f} €  {plan['credits']:>4} /mois")
print(
    "\nÀ comparer À LA MAIN avec les fiches App Store Connect : ce script ne "
    "voit pas\nce qu'Apple affiche à l'acheteuse, et c'est là que l'écart coûte cher."
)
