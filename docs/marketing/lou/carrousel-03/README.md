# Carrousel 03 — « Spécial messieurs »

Six visuels Instagram de 1080 × 1350 (4:5), à publier dans l'ordre. Même style « carnet » que les carrousels 01 et 02 : photos façon pellicule argentique, tirages, papier crème, écriture manuscrite. Aucune mention IA sur les visuels.

| # | Fichier | Contenu |
|---|---|---|
| 1 | `01-couverture.jpg` | « Spécial messieurs — ce carnet-là, c'est pour vous ». Lou tient les deux montres, avec « classique ou audacieuse ? » sur le tirage |
| 2 | `02-la-montre.jpg` | Poignet d'homme et montre à cadran vert : « Arrêtez de deviner. 1 photo de votre poignet, et vous voyez les deux. » |
| 3 | `03-la-chemise.jpg` | La chemise bleu cobalt : « celle que vous n'avez jamais osé porter. Spoiler : elle vous va. » |
| 4 | `04-comment.jpg` | Comment faire, avec une vraie capture de l'app : « Pas de vendeur. Pas de cabine. Pas de risque. » |
| 5 | `05-pour-elle.jpg` | Le paquet cadeau : « Et le cadeau pour elle ? », à essayer sur sa photo avec son accord |
| 6 | `06-osez.jpg` | L'Écrin Virtuel, « Allez, osez. C'est gratuit d'essayer. », App Store |

## Version « éditorial » (`edito/`)

Les mêmes six slides existent aussi en style magazine, dans le dossier `edito/` ([planche](edito/planche.jpg)) :
- la couverture est une photo plein cadre ;
- les slides de contenu ont la photo en haut et le texte sur un bandeau encre ;
- la slide 4 montre la capture de l'app sur fond encre ;
- la dernière slide est sur fond encre.

Il n'y a aucune mention d'IA sur les visuels. Pour les régénérer : `python3 scripts/lou-carousel-edito.py 01 02 03`.

## Légende

> Messieurs, ce carnet est pour vous ⌚ Montre classique ou audacieuse ? Chemise bleu cobalt ? Cadeau pour elle ? Arrêtez de deviner : essayez avant d'acheter. Zéro vendeur, zéro risque.
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #CarnetDeLou #ModeHomme #Montre #StyleHomme #IdéeCadeau #IA

À la publication, active l'étiquette IA d'Instagram (Paramètres avancés → « Ajouter une étiquette IA »).

## Fabrication

Les photos viennent de fal `nano-banana-2/edit` en 2K, au format 4:5, avec en référence le portrait de Lou et sa planche de continuité. Exception : la photo du poignet d'homme a été générée par `nano-banana-2`, sans référence, car la référence de Lou bloquait la génération. Les originaux sont dans `photos/`.
