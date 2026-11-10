# Higgsfield API : exemple Seedance 2.5

Un script Python qui génère une vidéo avec `bytedance/seedance-2.5/text-to-video` (« A cinematic scene at sunset », 5 s, 720p, 16:9) et affiche l'URL de la vidéo.

**Chaque exécution est une génération facturée** sur le solde de l'API Higgsfield.

## Installation

```bash
cd tools/higgsfield
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Le SDK officiel est `higgsfield-client` (Python 3.8+). Les identifiants se lisent avec `python-dotenv`.

## Clé API

1. Crée une clé dans la console Higgsfield (bouton « Create API key »). Tu obtiens un identifiant et un secret.
2. Écris-les dans `tools/higgsfield/.env.local`, sur une seule ligne, sous la forme `identifiant:secret` :

   ```
   HF_KEY=ton-identifiant:ton-secret
   ```

3. Ne colle jamais la clé dans un chat, un ticket ou un fichier versionné. `.env.local` est dans `.gitignore`. Vérification : `git check-ignore -v tools/higgsfield/.env.local`.

La clé reste côté serveur (ce script ne l'affiche ni ne la journalise). Le SDK TypeScript lirait `HF_CREDENTIALS` au lieu de `HF_KEY`, mais ce dépôt n'a pas de projet Node.

## Lancer

```bash
.venv/bin/python main.py
```

Le script ne conclut à un succès que si la demande est `Completed` **et** que la réponse contient `video.url`. Il s'arrête avec un code d'erreur dans ces cas :

| Cas | Code | Message |
|---|---|---|
| Clé absente ou mal formée | 1 | `HF_KEY is missing or malformed…` |
| Clé refusée, solde insuffisant, requête invalide | 1 | `The Higgsfield API refused the request: …` |
| Demande modérée (NSFW) | 1 | `Request was moderated…` |
| Demande annulée ou échouée | 1 | `Request was cancelled.` / `Request failed.` |

Le SDK ne lève pas d'exception pour un échec, une modération ou une annulation : `subscribe` attend l'état final et renvoie la réponse. Le script suit donc l'état avec `on_queue_update`.

## Références

- SDK : https://docs.higgsfield.ai/docs/how-to/sdk
- Modèle : https://console.higgsfield.ai/models/bytedance/seedance-2.5/text-to-video/api-reference
