# Punchlines de Lou : vidéos de 7 secondes

Quatre vidéos verticales de 1080 × 1920, de 6,9 à 7 s, son normalisé à −14 LUFS. Chacune suit la même structure :
1. **une accroche** en gros texte « natif TikTok » (noir sur bloc blanc, en haut), dès la première image ;
2. **une punchline** dite par Lou avec la voix MIMI, sous-titrée pour les 80 % qui regardent sans le son ;
3. **un appel à l'action** de 2 à 3 s sur fond flou (« Essaie gratuitement », L'Écrin Virtuel, App Store), avec un léger effet d'apparition.

Elles sont faites pour tourner en boucle.

| Fichier | Format repris | Accroche | Appel à l'action |
|---|---|---|---|
| `01-le-rouge.mp4` | POV transformation | « POV : tu oses ENFIN le rouge » | « Ta couleur interdite ? Essaie-la gratuitement » |
| `02-bague-3000.mp4` | Gros plan bijou + interdit levé | « Une bague à 3 000 €… sans entrer en boutique » | « Zéro vendeur. Zéro pression. Essaie gratuitement » |
| `03-messieurs.mp4` | Question de choix (commentaires) | « Messieurs : classique ou audacieuse ? » | « Réponds en commentaire. Essaie les deux, gratuit » |
| `04-reaction.mp4` | Réaction « je n'en reviens pas » + démo de l'app | « Personne ne m'avait dit ça… » | « Essaie n'importe quel bijou. Gratuit · lien en bio » |

## Ce qui marche en ce moment (vidIQ, 6 novembre 2026)

Source : recherche de vidéos « outliers » Instagram et TikTok depuis le 1er août 2026, c'est-à-dire des vidéos qui font bien plus de vues que la moyenne de leur créateur. Audience visée : France, 20-40 ans, mode et bijoux.

- **La réaction face caméra à une app, avec une question en texte** :
  - @dodo_parle_deco, 2,9 M de vues (317 fois sa médiane) : « Rassurez-moi, j'étais pas le seul à ne pas connaître ? » ;
  - @wassoutfit, 1,9 M (×1 459), sur une app d'essayage virtuel : « J'ai essayé la tenue d'un mec qui a 2 millions de vues ».

  → C'est la vidéo 04.
- **Le POV transformation** :
  - @stillo_app, 690 K (×19) : « POV: You let a stylist change EVERYTHING » ;
  - @elegancemajesty, 2,2 M.

  → C'est la vidéo 01.
- **Le bijou en gros plan dès la première image, court et en boucle** :
  - @roefastit7d, 507 K en 6 s ;
  - @buikiwtoyzm, 1,9 M en 8 s ;
  - @carbonandhyde, 705 K (×208).

  → C'est la vidéo 02.
- **La question de choix** :
  - @highlinediamond, 689 K : « WHICH ONE IS YOURS? » ;
  - @valeriya.crespi, 698 K (×101) en 9 s, sur une accroche « erreur ».

  → C'est la vidéo 03.
- **Points communs** : son dès la première frame, texte d'accroche lisible en moins d'une seconde, 6 à 10 s, et une fin qui reboucle.

## À la publication

- **Ajouter un son tendance** directement dans TikTok ou Instagram, à faible volume sous la voix. Les vidéos n'ont pas de musique pour que tu puisses choisir le son du moment.
- **Activer l'étiquette IA** de la plateforme. Il n'y a pas de mention « Personnage IA » à l'image.
- **Ajouter à la légende** : « Lou est un personnage créé par IA. »
- **Épingler un commentaire** avec le lien de l'App Store.
- **Publier les 4 vidéos** à deux ou trois jours d'intervalle, puis relancer en publicité (Spark Ads / boost) celle qui retient le mieux à 3 s.

## Refaire ou décliner

```bash
python3 scripts/lou-punchline.py docs/marketing/lou/punchlines/01-le-rouge.json sortie.mp4
```

Chaque plan JSON indique l'accroche, les segments (clip ou image, durée, sous-titre, recadrage) et l'appel à l'action. Le seul nouveau plan est la réaction de la vidéo 04 : la réplique MIMI « Attends… pourquoi personne m'a dit qu'on pouvait faire ça ?! », synchronisée sur l'image clé `v3/v3-p4.png`.
