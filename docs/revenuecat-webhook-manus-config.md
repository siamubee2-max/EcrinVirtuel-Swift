# Webhook RevenueCat « manus » — relevé de configuration (9 août 2026)

Relevé avant toute décision, pour que le webhook soit **reproductible à l'identique**.
RevenueCat ne propose pas de désactivation : la seule action disponible est la suppression.

## Configuration exacte

| Champ | Valeur |
|---|---|
| Webhook name | `manus` |
| Webhook URL | `https://manus.im/app/v6hrtfrcXEpbiq2dsLLsKi?vnc=1` |
| Authorization header value | *(vide — aucune authentification)* |
| HMAC webhook signing | Disabled |
| Environment to send events for | Both Production and Sandbox |
| Events filter → App | All apps |
| Events filter → Event type | All events |
| Send paywall events to Webhooks | non coché |
| Noms d'événements paywall | valeurs par défaut (`PAYWALL_CLOSE`, `PAYWALL_CANCEL`, `PAYWALL_EXIT_OFFER`, `PAYWALL_COMPONENT_INTERACTED`) |
| ID interne RevenueCat | `whintgrf568e3cf7a` |
| Webhook Events (historique) | « No Events to show » |

## Pourquoi c'est signalé

`manus.im` est une plateforme d'agents IA tierce — ce n'est pas une infrastructure du projet.
Ce webhook transmet **tous** les événements RevenueCat d'Écrin (identifiants clients,
produits, identifiants de transaction, montants, horodatages), en production **et** en
sandbox, **sans aucune authentification ni signature**.

Aucun autre webhook du projet ne pointe vers un tiers.

## Recréer à l'identique

Integrations → Webhooks → *Add new configuration*, puis reporter le tableau ci-dessus.

## Note

L'historique affichait « No Events to show » au moment du relevé — ce qui peut signifier
qu'aucun événement récent n'a été livré, ou que les livraisons échouent. Cela ne prouve
pas que rien n'a jamais transité.
