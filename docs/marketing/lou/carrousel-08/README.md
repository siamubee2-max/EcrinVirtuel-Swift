# Carrousel 08 — « Pas que des bijoux » (la garde-robe virtuelle)

Six visuels de 1080 × 1350 en style éditorial, dans `edito/` ([planche](edito/planche.jpg)). Ce carrousel montre que l'app ne s'arrête pas aux bijoux : elle gère aussi les vêtements, les chaussures et les accessoires. Il n'y a aucune mention d'IA sur les visuels.

| # | Fichier | Contenu |
|---|---|---|
| 1 | `01-couverture.jpg` | Lou en trench, sac, lunettes dans les cheveux, bracelet et collier : « Pas que des bijoux. » |
| 2 | `02-accessoires.jpg` | Flat lay sac, ceinture, lunettes, foulard, chapeau : « Tout un dressing » |
| 3 | `03-garde-robe.jpg` | Vraie capture de la garde-robe : « Numérise, compose, essaie. » Bijoux, vêtements, chaussures, accessoires |
| 4 | `04-looks.jpg` | « Mélange tout » : haut, bas, chaussures, accessoires, vus sur ta photo |
| 5 | `05-comment.jpg` | Slide texte : « En 3 gestes » |
| 6 | `06-ose.jpg` | « Ose tout essayer. » + « Dis-moi : tu essaies quoi en premier ? » |

Ce que dit le carrousel est vérifié dans le code de l'app : les catégories de la garde-robe sont Bijoux, Vêtements, Chaussures et Accessoires, et ces derniers couvrent sac, lunettes, ceinture, chapeau, écharpe et gants.

⚠️ **Chevillère** : elle n'est pas citée, parce qu'elle n'est pas une catégorie de la garde-robe (le code la traite comme un bracelet). À ajouter dans l'app avant d'en parler.

## Légende

> Je ne parle pas que de bijoux 👜🕶️ Dans ma garde-robe virtuelle, il y a aussi mes sacs, mes lunettes, mes ceintures, mes écharpes… et je les essaie tous avant de choisir. Toi, tu essaies quoi en premier ? 👇
>
> Lou est un personnage créé par IA.
>
> #LÉcrinVirtuel #GardeRobe #Accessoires #Sac #Lunettes #OseTonStyle #IA

À la publication, active l'étiquette IA d'Instagram.

## Fabrication

- **Photos** (`photos/`) : fal `nano-banana-2/edit` avec les références de Lou ; le flat lay vient de `nano-banana-2`, sans référence. Rendu pellicule, sans texte dans l'image.
- **Slides** : `python3 scripts/lou-carousel-edito.py 08`.
