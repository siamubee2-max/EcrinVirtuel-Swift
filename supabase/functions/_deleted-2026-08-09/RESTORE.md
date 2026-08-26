# Fonctions supprimées de la prod — 9 août 2026

Supprimées de `itjtshfzpknlzownpwte` après l'audit 007 : vestiges de l'app web Replit,
**aucun appelant** (ni dans l'app Swift, ni ailleurs dans le dépôt), et `ecrin.app` — le
domaine qui les consommait — n'a plus d'enregistrement DNS A.

| Fonction | Version supprimée | Garde d'auth | Dernière maj prod |
|---|---|---|---|
| `credits-check`  | v9  | JWT requis | 2026-04-27 |
| `try-on`         | v9  | JWT requis | 2026-04-27 |
| `device-tryon`   | v10 | **aucune** (GET → 405) | 2026-07-02 |

⚠️ `device-tryon` avait été redéployée le 2026-07-02 sans commit correspondant — sans doute
un déploiement manuel via le Dashboard. Si un comportement casse, c'est la première à
restaurer.

## Restaurer

```bash
cd /Volumes/EVO/EcrinVirtuel-Swift
cp -r supabase/functions/_deleted-2026-08-09/<nom> supabase/functions/<nom>
supabase functions deploy <nom> --project-ref itjtshfzpknlzownpwte
```

`device-tryon` était déployée **sans vérification de JWT**. Pour reproduire ce comportement
il faut `--no-verify-jwt` — mais ne le refaites pas sans raison : c'était un des constats
de l'audit.

La table `device_tryons` n'a **pas** été touchée (RLS activée, sans policy → service_role
uniquement depuis la migration 008).
