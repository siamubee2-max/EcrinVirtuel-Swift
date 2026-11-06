# Calendrier de publication de Lou : 2 semaines, 2 posts par jour

Stock disponible : 40 contenus.
- 5 vidéos longues (`videos/`) ;
- 26 punchlines de 7 s (`punchlines/`) ;
- 9 carrousels (`carrousel-01` à `09`), chacun en version « carnet » et en version « éditorial » (`edito/`), sauf les carrousels 06 à 09, qui n'existent qu'en éditorial.

Le planning en consomme 28 : les 5 vidéos, les 9 carrousels et 14 punchlines. Il reste 12 punchlines en réserve.

## Horaires

- **Midi (12 h 30)** : une punchline, format court et léger. C'est la pause déjeuner, le scroll est rapide. Elle sert aussi de **bande-annonce** : elle annonce le sujet du contenu du soir.
- **Soir (19 h 30 – 21 h)** : le contenu « fort », carrousel ou vidéo longue. C'est le pic d'audience FR sur Instagram et TikTok, avec plus de temps de lecture.

Les carrousels passent sur Instagram. Sur TikTok, publie-les en **mode photo** : même visuels, son tendance.

## Planning

Les fonctions garde-robe virtuelle et look du jour selon la météo passent en premier : elles sont dans les 5 premiers jours.

| Jour | Midi (bande-annonce) | Soir |
|---|---|---|
| J1 | Punchline 04 Réaction | Vidéo 01 « Enchantée, moi c'est Lou » |
| J2 | Punchline 21 Il pleut ? | **Carrousel 09 Je mets quoi selon la météo ?** (look du jour) |
| J3 | Punchline 01 Le rouge | Vidéo 02 « J'aurais jamais osé : le rouge » |
| J4 | Punchline 24 Pas que les bijoux | **Carrousel 08 Pas que des bijoux** (garde-robe virtuelle) |
| J5 | Punchline 22 Je mets quoi ? | **Vidéo 05 « Je mets quoi ? »** (garde-robe + météo) |
| J6 | Punchline 13 Celles qui attendent | Carrousel 01 Ce que j'ai osé essayer |
| J7 | Punchline 02 Bague 3 000 € | Vidéo 03 « Le bijou à 3 000 € » |
| J8 | Punchline 08 Couleur interdite (appel aux commentaires) | Carrousel 04 Couleurs |
| J9 | Punchline 15 Pas en vrai | Carrousel 02 La bague à 3 000 € |
| J10 | Punchline 03 Messieurs | Vidéo 04 « Spécial messieurs » |
| J11 | Punchline 11 Bleu marine | Carrousel 03 Spécial messieurs |
| J12 | Punchline 05 L'erreur | Carrousel 05 Collier × décolleté |
| J13 | Punchline 25 Soleil | Carrousel 06 Or ou argent ? |
| J14 | Punchline 26 Armoire | Carrousel 07 Le stack de bagues parfait |

Les enchaînements sont voulus :
- **J2, J4, J5** : la punchline de midi annonce le sujet du soir (pluie → météo, « pas que les bijoux » → garde-robe, « je mets quoi ? » → vidéo 05) ;
- **J10 et J11** : deux jours « messieurs » de suite, vidéo puis carrousel ;
- **J13** : la punchline « Soleil » précède le test or ou argent, qui se fait à la lumière du jour.

## Réserve

À garder pour une date, une réponse à un commentaire ou une semaine 3.

| Contenu | Pour quoi faire |
|---|---|
| **Vidéo 06 « Messieurs, je mets quoi ? »** | À poster 1 à 2 jours après la vidéo 04 (J10) ou en semaine 3 : même public messieurs, fonction garde-robe et météo |
| Punchline 07 Cadeau | Une date cadeau (Noël, Saint-Valentin) |
| Punchline 23 Dressing dans ma poche | Un deuxième passage sur la garde-robe, si le carrousel 08 marche bien |
| Punchlines 06 Cabine, 09 Attends, 10 Zéro euro | Remplacer une punchline qui n'accroche pas |
| Punchlines 12 Un loyer, 14 Dans chaque groupe, 16 Le vrai luxe, 17 Qu'elle a choisi | Idem, côté luxe et choix |
| Punchlines 18 Bijoux jamais portés, 19 La vendeuse, 20 Dimanche | Idem |

Il n'y a pas de réserve côté soir : tous les carrousels et toutes les vidéos sont utilisés. Pour la semaine 3, on reprend les 2 meilleurs de la semaine, ou on en produit de nouveaux.

**Style des carrousels.** Choisis un style et garde-le sur tout le fil, pour que le profil reste cohérent : la version éditorial (`edito/`) ou la version carnet. Les carrousels 06 à 09 n'existent qu'en éditorial, donc c'est le choix le plus simple.

## Routine de chaque post

1. **Son tendance** ajouté dans l'app, bas sous la voix. Les vidéos n'ont volontairement pas de musique.
2. **Étiquette IA** activée, plus la ligne « Lou est un personnage créé par IA. » dans la légende.
3. **Commentaire épinglé** avec le lien de l'App Store.
4. **Dans l'heure qui suit**, répondre aux premiers commentaires. La réponse en vidéo marche très bien : « Lou teste ta couleur ».

## Ce qu'on ne dit pas

La chevillère n'est pas une catégorie de la garde-robe de l'app, donc aucun contenu n'en parle. Tant qu'elle n'y est pas, évite de la citer en commentaire ou en réponse.

## Mesurer et réinvestir

- Au bout de 48 h, regarder la **rétention à 3 s** des vidéos et les **enregistrements** des carrousels.
- Compare en particulier les contenus garde-robe et météo (J2, J4, J5) aux contenus bijoux : ça dit sur quelle fonction insister en semaine 3.
- Les 2 meilleurs posts de la semaine passent en Spark Ads (TikTok) ou en boost (Instagram).
- Le format gagnant est décliné en 3 nouvelles versions la semaine suivante. Le script `scripts/lou-punchline.py` produit une punchline en quelques minutes à partir d'une photo et d'une phrase, et `scripts/lou-carousel-edito.py` régénère les carrousels.
