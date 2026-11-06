# Storyboard — Vidéo 05 « Je mets quoi ? »

| | |
|---|---|
| **Format** | 9:16 vertical, 1080 × 1920 |
| **Durée** | ≈ 24 s, 6 plans, plus le carton final |
| **Rubrique** | « La garde-robe virtuelle et le look du jour » |
| **Objectif** | Montrer que l'app ne fait pas que les bijoux : elle gère toute la garde-robe et propose la tenue du jour selon la météo |
| **Ton** | Complice, un peu exaspéré au début, puis soulagé |
| **Musique** | Pop légère, ≈ 100 BPM, à ajouter dans l'app de publication |
| **Sous-titres** | Blanc avec contour sombre, mots-clés en doré (#C9A24B) |
| **Mention IA** | Aucune sur les visuels. Elle passe par la légende, l'étiquette Instagram et la bio |
| **Garde-fous** | Ne promettre que ce que l'app fait : météo de la ville (Open-Meteo), pièces de la garde-robe d'abord, bouton « Essayer ». Pas de chevillère (pas dans la garde-robe) |

---

## Plan 1 — La question · 0:00 → 0:04
- **Cadre** : plan rapproché, devant l'armoire grande ouverte.
- **Action** : mains sur les hanches, sourcils levés.
- **Voix** : « Chaque matin, la même question : je mets quoi ? »
- **Texte** : « je mets **quoi** ? »

## Plan 2 — La météo · 0:04 → 0:09
- **Cadre** : plan rapproché, sur le canapé, près d'une fenêtre pluvieuse.
- **Action** : elle tient son téléphone vers nous, sûre d'elle (écran non lisible).
- **Voix** : « Ma réponse : mon appli regarde la météo, et me propose ma tenue. »
- **Texte** : « la météo **décide** »
- **⚠️ Au montage** : poser la vraie capture du « Look du jour » (`docs/appstore/screenshots-framed/05-lookdujour-framed.png`).

## Plan 3 — La garde-robe · 0:09 → 0:14
- **Cadre** : plan rapproché, à côté de l'armoire.
- **Action** : elle montre un foulard en soie et un sac en cuir, enthousiaste.
- **Voix** : « Elle pioche d'abord dans ma garde-robe : mes hauts, mes chaussures, mes accessoires. »
- **Texte** : « ma garde-robe **virtuelle** »
- **⚠️ Au montage** : insérer la capture de la garde-robe (`02-garderobe-framed.png`).

## Plan 4 — Le look · 0:14 → 0:19
- **Cadre** : plan rapproché, devant un grand miroir.
- **Action** : en trench, lunettes dans les cheveux, sac au bras, pouce levé.
- **Voix** : « Et d'un appui sur Essayer, je vois la tenue sur moi. »
- **Texte** : « 1 appui = le **look** »

## Plan 5 — Pas que les bijoux · 0:19 → 0:23
- **Cadre** : gros plan.
- **Action** : elle repousse ses lunettes dans ses cheveux et sourit.
- **Voix** : « Sac, lunettes, ceinture… et les bijoux, bien sûr. »
- **Texte** : « pas que les **bijoux** »

## Plan 6 — Le défi · 0:23 → 0:27
- **Cadre** : gros plan, grand sourire.
- **Action** : elle fait un clin d'œil, les yeux ouverts pour la synchro labiale.
- **Voix** : « Essaie. C'est gratuit. »
- **Texte** : « **Ose.** C'est gratuit »
- **Carton final** (2,5 s) : « L'Écrin Virtuel · Ose. C'est gratuit d'essayer. · Disponible sur l'App Store ».

---

## Légende et hashtags

> Chaque matin, la même question : je mets quoi ? 👗☔ Mon appli regarde la météo, pioche dans ma garde-robe et me montre la tenue sur moi. Sac, lunettes, ceinture, bijoux : tout s'essaie. Et toi, tu portes quoi aujourd'hui ?
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #LookDuJour #GardeRobe #OOTD #JeMetsQuoi #OseTonStyle #IA

## Production

Même chaîne que les vidéos 3 et 4 :
- **Images clés** : fal `nano-banana-2/edit`, références portrait et planche de continuité, aucun texte dans l'image.
- **Voix** : V1 MIMI, fichiers `lou/voix-mimi/v5-p*.mp3`.
- **Animation** : `fal-ai/infinitalk` puis `fal-ai/video-upscaler` ×2.
- **Montage** : `scripts/lou-montage.py` avec `lou/montage-video-05.json`.

---

## Plans générés (images clés)

| Plan | Image clé |
|---|---|
| 1 La question | [png](lou/v5/v5-p1.png) |
| 2 La météo | [png](lou/v5/v5-p2.png) |
| 3 La garde-robe | [png](lou/v5/v5-p3.png) |
| 4 Le look | [png](lou/v5/v5-p4.png) |
| 5 Pas que les bijoux | [png](lou/v5/v5-p5.png) |
| 6 Le défi | [png](lou/v5/v5-p6.png) |

Le premier essai du plan 4 a été refusé par le filtre de contenu de fal (rien n'a été facturé). Le prompt a été simplifié, sans le pouce levé.

Reste à faire : voix MIMI, synchro labiale et upscale, montage, puis les vraies captures de l'app aux plans 2 et 3.
