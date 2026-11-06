# Carrousel 09 — « Je mets quoi selon la météo ? » (le look du jour)

Six visuels de 1080 × 1350 en style éditorial, dans `edito/` ([planche](edito/planche.jpg)). Ce carrousel présente la fonction « Look du jour » : l'app regarde la météo de ta ville et te propose une tenue. Il n'y a aucune mention d'IA sur les visuels.

| # | Fichier | Contenu |
|---|---|---|
| 1 | `01-couverture.jpg` | Lou regarde son téléphone devant une fenêtre sous la pluie : « Je mets quoi selon la météo ? » |
| 2 | `02-pluie.jpg` | Pluie : le trench ceinturé, le sac en cuir, un foulard |
| 3 | `03-soleil.jpg` | Soleil : robe légère, chapeau, lunettes, bracelet fin |
| 4 | `04-froid.jpg` | Froid : manteau, écharpe, sac |
| 5 | `05-look-du-jour.jpg` | Vraie capture du « Look du jour » : « L'app regarde la météo de ta ville… », puis « Essayer » |
| 6 | `06-ose.jpg` | « Quel temps chez toi ? Ta tenue du jour, en 1 appui. » |

Ce que dit le carrousel est vérifié dans le code de l'app : le look du jour est calculé avec la météo (Open-Meteo) et choisit d'abord des pièces de ta garde-robe, puis complète avec le catalogue. Le bouton « Essayer » montre la tenue. La capture porte déjà la mention de la source météo.

## Légende

> Pluie, soleil ou froid : je mets quoi ? ☔☀️❄️ Mon appli regarde la météo et me propose ma tenue du jour avec ce que j'ai déjà dans ma garde-robe. Un appui sur « Essayer », et je vois le résultat. Quel temps chez toi aujourd'hui ?
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #LookDuJour #OOTD #Météo #GardeRobe #Style #IA

À la publication, active l'étiquette IA d'Instagram.

## Fabrication

- **Photos** (`photos/`) : fal `nano-banana-2/edit` avec les références de Lou, sans texte dans l'image. Le trench de la slide 2 vient de `../carrousel-08/photos/a-cover.jpg`.
- **Slides** : `python3 scripts/lou-carousel-edito.py 09`.
