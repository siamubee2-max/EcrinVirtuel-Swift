# Carrousel 01 — « Le carnet de Lou »

Six visuels Instagram de 1080 × 1350 (4:5), à publier dans l'ordre.

Le parti pris : un carnet artisanal plutôt qu'un rendu « IA ». Concrètement :
- photos façon pellicule argentique (Portra 400, grain, cadrage imparfait) ;
- tirages à bord blanc posés de travers et tenus par du masking tape ;
- papier crème, légendes manuscrites (Caveat), titres en Cormorant Garamond.

| # | Fichier | Contenu |
|---|---|---|
| 1 | `01-couverture.jpg` | « Le carnet de Lou — tout ce que j'ai osé essayer cette semaine » |
| 2 | `02-le-rouge.jpg` | Le rouge : « Dix ans que je me disais c'est pas pour moi. Verdict ? canon. » |
| 3 | `03-faits-main.jpg` | Pierres brutes et or fin : « derrière chaque bijou, il y a des mains » |
| 4 | `04-mon-secret.jpg` | Le secret : une vraie capture de l'app (`docs/appstore/screenshots-framed/01-essayage-framed.png`) |
| 5 | `05-et-toi.jpg` | L'appel au commentaire : « c'est quoi la couleur que tu n'as jamais osé porter ? » |
| 6 | `06-ose.jpg` | L'Écrin Virtuel, « Ose. C'est gratuit d'essayer. », App Store |

Aucune mention IA sur les visuels (choix du 6 novembre 2026). L'information passe donc par trois autres canaux, à ne pas oublier :
- **à la publication**, activer l'étiquette « Informations sur l'IA » d'Instagram (Paramètres avancés → « Ajouter une étiquette IA ») ;
- **dans la légende**, la dernière ligne ci-dessous ;
- **dans la bio** de @lou.ecrin, la mention « personnage IA ».

C'est ce qu'exigent l'article 50 du règlement européen sur l'IA, pour un personnage synthétique réaliste, et les règles de Meta.

## Version « éditorial » (`edito/`)

Les mêmes six slides existent aussi en style magazine, dans le dossier `edito/` ([planche](edito/planche.jpg)) :
- la couverture est une photo plein cadre ;
- les slides de contenu ont la photo en haut et le texte sur un bandeau encre ;
- la slide 4 montre la capture de l'app sur fond encre ;
- la dernière slide est sur fond encre.

Il n'y a aucune mention d'IA sur les visuels. Pour les régénérer : `python3 scripts/lou-carousel-edito.py 01 02 03`.

## Légende

> Mon carnet de la semaine 📓 Le rouge (enfin), des pierres brutes, et un petit secret pour tout essayer sans cabine. Et toi, c'est quoi la couleur que tu n'as jamais osé porter ? Dis-le-moi en commentaire, je la teste pour toi 🤍
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #CarnetDeLou #FaitMain #BijouxArtisanaux #PierresNaturelles #OseTonStyle #IA

## Fabrication

- **Photos** : fal `nano-banana-2/edit` en 2K, au format 4:5. Références : le portrait de Lou et sa planche de continuité. Prompt « candid analog 35mm film, Kodak Portra 400 ». Originaux dans `photos/`.
- **Mise en page** : script Pillow (papier, grain, tirages, ruban, typographies Google Fonts).
