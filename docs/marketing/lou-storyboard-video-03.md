# Storyboard — Vidéo 03 « Le bijou à 3 000 € »

| | |
|---|---|
| **Format** | 9:16 vertical, 1080 × 1920 |
| **Durée** | ≈ 32 s, 7 plans, plus le carton final |
| **Rubrique** | « Le bijou à 3 000 € » |
| **Objectif** | Montrer qu'on peut essayer un bijou hors de prix sans pression, puis ouvrir sur l'idée cadeau pour les hommes |
| **Ton** | Complice et un peu taquin : la gêne en boutique, puis l'émerveillement, puis le clin d'œil aux messieurs |
| **Musique** | Pop chic et légère, ≈ 105 BPM. Un « ding » cristallin sur l'apparition de la bague (plan 4) |
| **Sous-titres** | Blanc avec contour sombre, mots-clés en doré (#C9A24B), la couleur de l'or |
| **Mention IA** | « Personnage IA » en petit en haut à gauche pendant toute la vidéo, plus le carton final |
| **Garde-fous** | Le prix cité est celui du bijou, jamais celui de l'abonnement. Pas de marque de joaillerie visible. On ne promet pas un rendu « identique à la réalité » |

---

## Plan 1 — La question · 0:00 → 0:04
- **Cadre** : plan rapproché, appartement lumineux.
- **Action** : Lou tend sa main gauche nue vers l'objectif, doigts écartés, un sourcil levé.
- **Voix** : « Petite question : t'as déjà essayé une bague à trois mille euros ? »
- **Texte** : « une bague à **3 000 €** ? »
- **Pourquoi** : le chiffre crée la curiosité dès la première seconde.

## Plan 2 — L'aveu · 0:04 → 0:09
- **Cadre** : plan taille, dans une rue parisienne en fin de journée, devant la vitrine d'une joaillerie (sans enseigne lisible).
- **Action** : Lou se retourne vers nous avec un sourire gêné.
- **Voix** : « Moi non plus. En boutique, j'ose même pas demander. »
- **Texte** : « j'ose **même pas** demander »
- **Pourquoi** : tout le monde connaît cette gêne.

## Plan 3 — L'essayage · 0:09 → 0:14
- **Cadre** : plan rapproché, sur le canapé.
- **Action** : elle photographie sa main avec son téléphone, puis sourit à la caméra.
- **Voix** : « Alors je l'essaie ici. Une photo de ma main… et voilà. »
- **Texte** : « 1 photo de ma **main** »
- **⚠️ Au montage** : remplacer l'écran du téléphone par une vraie capture de l'app.

## Plan 4 — La révélation · 0:14 → 0:19
- **Cadre** : gros plan, lumière chaude.
- **Action** : elle approche de son visage sa main ornée d'un gros solitaire en diamant et le regarde, émerveillée.
- **Voix** : « Ça me va ? Ça me va pas ? Je sais exactement ce que je veux. »
- **Texte** : « je sais ce que je **veux** »
- **Son** : « ding » cristallin à l'apparition de la bague.

## Plan 5 — Sans pression · 0:19 → 0:23
- **Cadre** : plan taille, appartement.
- **Action** : elle rit, détendue, la main baguée posée sur la poitrine.
- **Voix** : « Sans pression, et sans vendeur qui me regarde de travers. »
- **Texte** : « **0** pression · **0** vendeur »

## Plan 6 — L'idée cadeau · 0:23 → 0:28
- **Cadre** : plan rapproché.
- **Action** : elle ouvre un petit écrin ivoire à ruban doré et nous le montre.
- **Voix** : « Et le plus fou ? Tu peux faire pareil avant d'offrir un cadeau. »
- **Texte** : « parfait avant d'**offrir** »

## Plan 7 — Spécial messieurs · 0:28 → 0:33
- **Cadre** : gros plan.
- **Action** : elle pointe la caméra et fait un clin d'œil.
- **Voix** : « Messieurs, prenez des notes. Ose : c'est gratuit d'essayer. »
- **Texte** : « Messieurs, **prenez des notes** »
- **Carton final** (2,5 s) : « L'Écrin Virtuel · Ose. C'est gratuit d'essayer. · Disponible sur l'App Store · Lou est un personnage créé par IA ».

---

## Légende et hashtags

> T'as déjà essayé une bague à 3 000 € ? 💍 Moi non plus… jusqu'à aujourd'hui. Zéro pression, zéro vendeur, et une idée cadeau imparable. Messieurs, prenez des notes 😉
>
> #LÉcrinVirtuel #EssayageVirtuel #BagueDeFiançailles #IdéeCadeau #Bijoux #Joaillerie #IA

## Production

- **Images clés** : fal `nano-banana-2/edit`, en 9:16. Références : le portrait de Lou et sa planche de continuité. Chaque prompt interdit tout texte dans l'image : les images des vidéos 1 et 2 en contenaient, il a fallu les effacer ou recadrer.
- **Voix** : V1 MIMI (ElevenLabs), une réplique par plan, dans `lou/voix-mimi/v3-p*.mp3`.
- **Animation** : `fal-ai/infinitalk` (480p), puis `fal-ai/video-upscaler` (×2).
- **Montage** : `scripts/lou-montage.py` avec `lou/montage-video-03.json`.
