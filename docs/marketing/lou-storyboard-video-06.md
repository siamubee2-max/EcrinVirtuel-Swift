# Storyboard — Vidéo 06 « Messieurs, je mets quoi ? »

| | |
|---|---|
| **Format** | 9:16 vertical, 1080 × 1920 |
| **Durée** | ≈ 22 s, 6 plans, plus le carton final |
| **Rubrique** | « Spécial messieurs » : la version masculine de la vidéo 05 (garde-robe et look du jour selon la météo) |
| **Objectif** | Montrer aux hommes que l'app propose une tenue du jour selon la météo, avec leurs pièces, et qu'elle ne s'arrête pas à la montre |
| **Ton** | Complice et taquin, Lou vouvoie les hommes comme dans la vidéo 04 |
| **Musique** | Groove léger, ≈ 100 BPM, à ajouter dans l'app de publication |
| **Sous-titres** | Blanc avec contour sombre, mots-clés en doré (#C9A24B) |
| **Mention IA** | « Personnage IA » en haut à gauche, plus le carton final, comme les vidéos 1 à 5 |
| **Garde-fous** | Aucun homme réel à l'image, donc rien à faire valider : Lou présente des vêtements sur cintre. Ne promettre que ce que l'app fait : choix Homme / Femme / Unisexe dans le look du jour, météo de la ville, pièces de la garde-robe d'abord, bouton « Essayer » sur sa propre photo. Pas de marque visible |

---

## Plan 1 — La question · 0:00 → 0:04
- **Cadre** : plan rapproché, devant une penderie d'homme (chemises, vestes, ceintures sur cintres).
- **Action** : Lou lève les yeux au ciel, un cintre dans chaque main, taquine.
- **Voix** : « Messieurs, chaque matin, la même question : je mets quoi ? »
- **Texte** : « je mets **quoi** ? »

## Plan 2 — La météo · 0:04 → 0:09
- **Cadre** : plan rapproché, sur le canapé, fenêtre sous la pluie.
- **Action** : elle tend son téléphone vers nous, sûre d'elle (écran non lisible).
- **Voix** : « Votre appli regarde la météo, et vous propose la tenue du jour. »
- **Texte** : « la météo **décide** »
- **⚠️ Au montage** : capture de l'app. Celle qui existe (`05-lookdujour-framed.png`) est réglée sur « Femme ». Pour être honnête, il faut une capture avec **Homme** sélectionné, à faire sur le simulateur. À défaut, utiliser la capture de la garde-robe, qui est neutre.

## Plan 3 — La garde-robe · 0:09 → 0:14
- **Cadre** : plan rapproché, à côté de la penderie.
- **Action** : elle montre une chemise bleu cobalt et une ceinture en cuir.
- **Voix** : « Elle pioche d'abord dans votre garde-robe : chemises, chaussures, montre, ceinture. »
- **Texte** : « votre garde-robe **virtuelle** »
- **⚠️ Au montage** : capture de la garde-robe (`02-garderobe-framed.png`).

## Plan 4 — Le look · 0:14 → 0:18
- **Cadre** : plan rapproché, devant un grand miroir.
- **Action** : elle tient une veste d'homme devant elle, l'air convaincu.
- **Voix** : « Un appui sur Essayer, et vous voyez la tenue sur vous. »
- **Texte** : « 1 appui = le **look** »

## Plan 5 — Pas que la montre · 0:18 → 0:22
- **Cadre** : gros plan.
- **Action** : elle fait tourner des lunettes de soleil entre ses doigts, avec un sourire en coin.
- **Voix** : « Montre, lunettes, ceinture… tout s'essaie. »
- **Texte** : « pas que la **montre** »

## Plan 6 — Le défi · 0:22 → 0:25
- **Cadre** : gros plan, grand sourire.
- **Action** : elle fait un clin d'œil avec un sourcil levé, les yeux ouverts pour la synchro labiale.
- **Voix** : « Messieurs, osez. C'est gratuit. »
- **Texte** : « **Osez.** C'est gratuit »
- **Carton final** (2,5 s) : « L'Écrin Virtuel · Ose. C'est gratuit d'essayer. · Disponible sur l'App Store · Lou est un personnage créé par IA ».

---

## Légende et hashtags

> Messieurs, chaque matin, la même question : je mets quoi ? 👔☔ L'appli regarde la météo, pioche dans votre garde-robe et vous montre la tenue sur vous. Chemise, montre, lunettes, ceinture : tout s'essaie. Zéro risque.
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #ModeHomme #LookDuJour #GardeRobe #StyleHomme #OOTD #IA

## Production prévue

Même chaîne que les vidéos 4 et 5 :
- **Images clés** : fal `nano-banana-2/edit`, références portrait et planche de continuité, aucun texte dans l'image. Éviter les gestes qui ont fait refuser le plan 4 de la vidéo 05 (pouce levé).
- **Voix** : V1 MIMI (ElevenLabs), fichiers `lou/voix-mimi/v6-p*.mp3`.
- **Synchro labiale** : Kie `kling/ai-avatar-standard` (720p), qui a fonctionné sur les plans 5 et 6 de la vidéo 05 là où fal et Kie InfiniTalk ont échoué. Les images clés sont d'abord redimensionnées en 720 × 1280 JPEG.
- **Montage** : `scripts/lou-montage.py` avec `lou/montage-video-06.json` (option `overlay` pour les captures).

Higgsfield (Intone) n'a pas été utilisé : la clé API n'a pas été fournie.
