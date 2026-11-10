# Pinterest : création du compte et épingles du J1

Je ne peux pas créer le compte à votre place : il faut votre e-mail, un mot de passe et l'acceptation des conditions, que vous seul(e) pouvez donner. Les 10 minutes ci-dessous suffisent, et les épingles sont prêtes.

## 1. Créer le compte (10 minutes)

1. Allez sur pinterest.com/business/create et créez un **compte professionnel** (gratuit), avec une adresse e-mail que vous gardez.
2. **Nom du profil :** `Lou · L'Écrin Virtuel`. Nom d'utilisateur suggéré : `lecrinvirtuel` (si pris, `lou.lecrinvirtuel`).
3. **Photo de profil :** `docs/marketing/lou/carrousel-02/photos/a-bague.jpg`, recadrée sur le visage.
4. **Bio (150 caractères max) :**
   ```
   Essaie bijoux, robes et couleurs sur ta photo avant d'acheter. Lou est un personnage créé par IA. App gratuite.
   ```
5. **Site web :** `https://inferencevision.store/ecrin/` (la page de l'app, qui répond bien). Pinterest permet de **revendiquer** ce site (réglages > Revendiquer un compte > Sites web) : c'est possible parce qu'il vous appartient, et ça affiche votre nom sous chaque épingle. Pinterest vous demandera d'ajouter une balise ou un fichier HTML sur le site : voir le point d'attention plus bas.
6. **Pays et langue :** France, français.
7. Dans les réglages, activez la mention **contenu généré par IA** si Pinterest la propose à la publication. L'étiquette « Lou est un personnage créé par IA » est déjà écrite sur chaque épingle et dans chaque description.

## 2. Tableaux à créer (6, publics)

| Tableau | Pour quoi |
|---|---|
| Essayer sans cabine | les épingles « une photo suffit » |
| Oser les couleurs | rouge, couleurs interdites |
| Bijoux : bagues, colliers, boucles | bijoux et leur essayage |
| Look du jour selon la météo | pluie, soleil, froid |
| Idées tenues pour messieurs | chemise, ceinture |
| Garde-robe virtuelle | rangement, tenues enregistrées |

Descriptions courtes, une phrase chacune, avec « Lou est un personnage créé par IA. » dans le premier tableau au moins.

## 3. Les 3 épingles du J1

Format 1000 × 1500 (2:3), dans `docs/marketing/lou/pinterest/`. Les épingles verticales 2:3 sont le format que Pinterest met en avant. Dans le champ « Lien de destination », mettez `https://inferencevision.store/ecrin/`.

### Épingle 1 : `j1-pin-1-sans-cabine.jpg` · tableau « Essayer sans cabine »
**Titre :** Essayer sans cabine : une photo suffit
**Description :**
```
Bijoux, robes, couleurs : vois-les sur toi avant d'acheter. Avec L'Écrin Virtuel, une photo de toi suffit pour essayer un look sans cabine d'essayage. Gratuit à essayer. Lou est un personnage créé par IA.
```
**Texte alternatif :** Lou, personnage créé par IA, assise près d'une fenêtre, souriante, avec un collier et des boucles d'oreilles.
**Mots-clés (dans la description ou en étiquettes) :** essayage virtuel, essayer des bijoux, cabine d'essayage, look du jour

### Épingle 2 : `j1-pin-2-le-rouge.jpg` · tableau « Oser les couleurs »
**Titre :** Le rouge que je n'avais jamais osé
**Description :**
```
Une robe rouge, enfin. Teste une couleur sur toi avant de t'engager : une photo, et tu vois si elle te va. Gratuit à essayer. Lou est un personnage créé par IA.
```
**Texte alternatif :** Lou, personnage créé par IA, en robe rouge dans un salon lumineux, en train de rire.
**Mots-clés :** robe rouge, oser la couleur, essayage virtuel

### Épingle 3 : `j1-pin-3-la-bague.jpg` · tableau « Bijoux : bagues, colliers, boucles »
**Titre :** Cette bague à 3 000 €, essayée sans entrer en boutique
**Description :**
```
Sans vendeur, sans pression : juste ta photo. L'Écrin Virtuel te montre une bague sur toi avant d'acheter. Gratuit à essayer. Lou est un personnage créé par IA.
```
**Texte alternatif :** Lou, personnage créé par IA, la main sur le menton, une bague solitaire au doigt.
**Mots-clés :** bague solitaire, essayer une bague, bijoux

## 4. Rythme conseillé

- **3 épingles le J1**, puis 1 à 2 par jour. Pinterest récompense la régularité : mieux vaut peu de pins chaque jour que 20 d'un coup.
- Une épingle Pinterest vit des semaines : on réutilise les photos et les carrousels existants (couvertures, visuels), pas besoin de nouvelles vidéos.
- Au bout de 2 semaines, regardez dans Pinterest Analytics les **clics sortants** et les **enregistrements** par épingle, et refaites les formats gagnants.

## Points d'attention

- **La page `/ecrin/` n'a pas de bouton « Télécharger sur l'App Store ».** Elle décrit l'app mais ne renvoie vers aucune boutique : un clic depuis Pinterest n'aboutit pas à une installation. Ajoutez le bouton sur la page avant de publier, ou mettez le lien App Store en destination des épingles.
- **Liens cassés sur la page (vérifié aujourd'hui) :** `/ecrin/privacy`, `/ecrin/terms` et `/ecrin/support`, vers lesquels la page pointe, renvoient une erreur 404. Les versions `.html` (`/ecrin/privacy.html`, etc.) fonctionnent. À corriger sur le site (redirection ou liens en `.html`), car Apple vérifie ces adresses.
- Pour revendiquer le site, la balise Pinterest se pose dans la page d'accueil du site. La source de `/ecrin/` n'est pas dans ce dépôt (seuls `privacy.html`, `support.html`, `terms.html` y sont) : ça se fait à l'endroit où vous déployez le site.
- « 3 000 € » : c'est le prix du bijou présenté dans le contenu de Lou, pas un prix de l'app. La description le dit : « gratuit à essayer ».
