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

---

## Plans générés (voix MIMI, synchro labiale fal, upscalés ×2)

| Plan | Image clé | 480p | Upscalé ×2 |
|---|---|---|---|
| 1 La question | [png](lou/v3/v3-p1.png) | [mp4](https://v3b.fal.media/files/b/0ab14427/_c_w2qK7LzYaFC9nnLZgF_F2C6r3ZZ.mp4) | [mp4](https://v3b.fal.media/files/b/0ab1443d/60uLZ5P_jCcOLL5acpbCb_sVtOHabb.mp4) |
| 2 L'aveu | [png](lou/v3/v3-p2.png) | [mp4](https://v3b.fal.media/files/b/0ab14431/DAx7aG3U3rjxbrY5fV9c0_L4kOvJwF.mp4) | [mp4](https://v3b.fal.media/files/b/0ab1443e/NFvTLvcWL-UQHkeXo59m2_KjyxedzQ.mp4) |
| 3 L'essayage | [png](lou/v3/v3-p3.png) | [mp4](https://v3b.fal.media/files/b/0ab14446/t5MRJYI9qAJ3uAWjwZqLR_AdlhhuB5.mp4) | [mp4](https://v3b.fal.media/files/b/0ab1444c/nnyJSo4vt-c-eCVabFvne_r08dBi6v.mp4) |
| 4 La révélation | [png](lou/v3/v3-p4.png) | [mp4](https://v3b.fal.media/files/b/0ab14552/HFhL-ixzKFO_3We7MNigy_ykfG5Cuy.mp4) | [mp4](https://v3b.fal.media/files/b/0ab14564/ff4F4VrI95itf1He0l5x5_okbBnd3f.mp4) |
| 5 Sans pression | [png](lou/v3/v3-p5.png) | [mp4](https://v3b.fal.media/files/b/0ab1455d/rRgNOetMmtJNODWhX6l8v_6J2uektI.mp4) | [mp4](https://v3b.fal.media/files/b/0ab14571/UA0TouQhE4Yu7LzbcS7E1_r7wStu0l.mp4) |
| 6 L'idée cadeau | [png](lou/v3/v3-p6.png) | [mp4](https://v3b.fal.media/files/b/0ab14567/Yfjz7vUHlR7dnpZWqroRo_ufOlkkE1.mp4) | [mp4](https://v3b.fal.media/files/b/0ab14573/OwpNaKYpOxd2es3f3liKy_rUMh72lv.mp4) |
| 7 Spécial messieurs | [png](lou/v3/v3-p7.png) | [mp4](https://v3b.fal.media/files/b/0ab1457b/F6DlLspXPTGHBryxTglLe_lWSm9Pmk.mp4) | [mp4](https://v3b.fal.media/files/b/0ab14581/BtcCZtz5-lFDI7zmkMMBQ_XHzM4YlK.mp4) |

Au plan 7, le clin d'œil prévu est devenu un sourcil levé, les yeux ouverts : un œil fermé figé sur toute la durée du plan rend mal avec la synchro labiale.

## Montage

→ [`lou/videos/lou-video-03.mp4`](lou/videos/lou-video-03.mp4) : 26,3 s, 1080 × 1920, voix MIMI, son normalisé à −14 LUFS.

Aucune retouche n'a été nécessaire : les images clés ne contiennent aucun texte incrusté.

Reste à faire dans CapCut :
- piste musicale, avec le « ding » au plan 4 ;
- vraie capture de l'app sur l'écran du téléphone au plan 3.
