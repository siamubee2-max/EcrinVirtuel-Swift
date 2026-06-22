# M4 — Runbook d'activation App Attest (Voie A, depuis le repo)

État : app iOS shippée (envoie les en-têtes App Attest). Côté serveur **pas encore déployé**
(`tryon-generate` en v22 sans hook, `verify-attestation` absente). Suivre ces étapes pour activer.

> Prérequis CLI : `supabase login` (ou `export SUPABASE_ACCESS_TOKEN=...`) une fois.
> Tout se fait depuis la racine du repo `/Volumes/EVO/EcrinVirtuel-Swift`.

## 1. Secrets (Dashboard → Project → Edge Functions → Secrets, ou via CLI)
```bash
# Le VRAI certificat racine Apple App Attest (jamais hardcodé — lu via env, fail-closed)
curl -s https://www.apple.com/certificateauthority/Apple_App_Attest_Root_CA.pem
#  → secret APPLE_APP_ATTEST_ROOT_CA_PEM = <le PEM complet, lignes BEGIN/END incluses>

# (Recommandé) secret partagé serveur-à-serveur, protège verify-attestation
#  → secret INTERNAL_FN_KEY = <une longue chaîne aléatoire>

# Le mode reste en OBSERVATION d'abord (n'enforce rien)
#  → secret APP_ATTEST_MODE = log
```
Via CLI (équivalent) :
```bash
supabase secrets set --project-ref itjtshfzpknlzownpwte \
  APPLE_APP_ATTEST_ROOT_CA_PEM="$(curl -s https://www.apple.com/certificateauthority/Apple_App_Attest_Root_CA.pem)" \
  INTERNAL_FN_KEY="$(openssl rand -hex 24)" \
  APP_ATTEST_MODE="log"
```

## 2. Déployer les 2 fonctions (verify_jwt déjà réglé par `supabase/config.toml`)
```bash
supabase functions deploy verify-attestation --project-ref itjtshfzpknlzownpwte   # verify_jwt=false (config.toml)
supabase functions deploy tryon-generate    --project-ref itjtshfzpknlzownpwte   # v23, hook OFF→log selon le secret
```
- ⚠️ `tryon-generate` = chemin de génération **payant**. Après deploy, fais **un essayage réel** : ça doit toujours rendre une image. Si KO → rollback (étape 5).

## 3. Valider sur device réel (mode `log`, ne bloque rien)
1. Sur un **iPhone réel** (App Attest ne marche pas en simulateur), build TestFlight (`appattest-environment=development`) ou App Store (`production`).
2. Faire 1-2 essayages.
3. Vérifier côté serveur (je peux le faire via MCP, ou toi en SQL) :
   - `select count(*) from device_attest;`  → doit devenir > 0 (clé(s) enregistrée(s)).
   - `select event_type, count(*) from monitoring_events where event_type like 'attestation%' group by 1;`
     → tu veux voir **`attestation_ok`**. Si `attestation_fail`, lire `error_message` (souvent le caveat DER-nesting du parser nonce → ajuster `extractOctetStringFromDer` dans verify-attestation).

## 4. Passer en enforce (seulement quand `attestation_ok` confirmé depuis de vrais devices)
```bash
supabase secrets set --project-ref itjtshfzpknlzownpwte APP_ATTEST_MODE="enforce"
```
- Dès lors, une requête sans attestation valide → HTTP 401 `attestation_required`. Borne l'abus de génération.

## 5. Rollback (à tout moment)
```bash
supabase secrets set --project-ref itjtshfzpknlzownpwte APP_ATTEST_MODE="off"   # désactive le hook instantanément
# ou revenir au code connu :
supabase functions deploy tryon-generate --project-ref itjtshfzpknlzownpwte  # depuis supabase/functions/tryon-generate/index.live-20260621.ts si besoin (renommer en index.ts)
```

## Notes
- `verify-attestation` **fail-closed** si `APPLE_APP_ATTEST_ROOT_CA_PEM` absent → pas de faux « ok ».
- Le hook ne casse JAMAIS la génération (try/catch total, timeout 3s) ; en `log` il observe seulement.
- La crypto `verify-attestation` est **non testée** par l'agent → c'est l'étape 3 (device réel) qui la valide.
