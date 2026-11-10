# Description App Store corrigée (français) — 10 novembre 2026

À coller dans App Store Connect > la version de l'app > Description (fr). Se modifie avec une nouvelle version de l'app.

## Pourquoi cette correction

Relevé sur la fiche publique (`https://apps.apple.com/fr/app/id6760768389`) le 10/11/2026 :

| Dans la description actuelle | Réalité (produits / serveur) |
|---|---|
| Starter — 4,99 €/mois | 6,99 €/mois (affiché « Essentiel ») |
| Premium — 9,99 €/mois | 14,99 €/mois (affiché « Signature ») |
| Elite, Édition Fondateur et prix annuels | retirés de la vente dans l'app (`PaywallView.allPlans` : deux formules mensuelles) |
| Packs 30 crédits 7,99 € et 70 crédits 16,99 € | n'existent plus : 40 crédits à 10,99 € |
| 150 crédits — 29,99 € | le serveur créditait 140 : repassé à 150 dans le code le 10/11/2026 (à déployer) |
| « Sécurité Face ID / Touch ID » | aucun code biométrique trouvé dans l'app |
| « Mode hors-ligne » des favoris | non trouvé dans le code (seule la météo gère l'absence de réseau) |
| Liens `/privacy`, `/terms`, `/faq` | erreur 404 ; les bons sont sous `/ecrin/…html` |

## Texte à coller

```
L'Écrin Virtuel — Votre cabine d'essayage virtuelle de bijoux, vêtements et accessoires.

› ESSAYEZ AVANT D'ACHETER
Bagues, colliers, boucles d'oreilles, bracelets, vêtements, chaussures et accessoires : visualisez chaque pièce sur votre propre photo grâce à l'IA, avant d'acheter.

› PHOTOGRAPHIEZ UNE PIÈCE
Une bague en vitrine, des boucles d'oreilles dans un magazine ? Prenez-la en photo et essayez-la sur vous.

› VOTRE COLLECTION PERSONNELLE
« Mon Écrin » est votre garde-bijoux virtuel. Sauvegardez vos essayages favoris, organisez vos pièces préférées, visualisez un bijou sous plusieurs angles et retrouvez tout en quelques secondes.

› STYLISTE IA AVEC SUGGESTIONS MÉTÉO
Le styliste IA vous propose des looks adaptés à votre journée et à la météo locale.

› TENUE COMPLÈTE ET COMPARAISON
Composez une tenue avec plusieurs pièces, comparez avant et après, ou placez deux pièces côte à côte pour décider sans pression.

L'essayage est un rendu généré par IA : la taille, la matière et la couleur réelles d'une pièce peuvent différer.

ABONNEMENTS (renouvellement automatique)
• Essentiel — 6,99 €/mois : 25 crédits d'essayage par mois
• Signature — 14,99 €/mois : 60 crédits par mois

Le paiement est débité sur votre compte Apple à la confirmation de l'achat. L'abonnement se renouvelle automatiquement, sauf annulation au moins 24 h avant la fin de la période en cours. Gérez ou annulez votre abonnement dans Réglages › [votre nom] › Abonnements.

PACKS DE CRÉDITS (achat unique)
• Spark — 10 crédits — 2,99 €
• Éclat — 40 crédits — 10,99 €
• Diamant — 150 crédits — 29,99 €

Les prix sont indiqués pour la France et peuvent varier selon le pays.

SUPPORT & CONTACT
Site : https://inferencevision.store/ecrin/
Politique de confidentialité : https://inferencevision.store/ecrin/privacy.html
Conditions générales : https://inferencevision.store/ecrin/terms.html
Assistance : https://inferencevision.store/ecrin/support.html
```

## À vérifier avant de coller (je ne vois pas App Store Connect)

1. **Diamant : 150 (décidé le 10/11/2026).** Le code (app, serveur, sandbox) est repassé à 150 pour correspondre au produit « Diamant — 150 Crédits » d'App Store Connect. Les deux fonctions `credit-generations` (v10) et `revenuecat-webhook` (v16) ont été redéployées le 10/11/2026 : le serveur crédite 150.
2. **Formules annuelles, Elite et Édition Fondateur : retirées du texte.** L'app ne propose que deux abonnements mensuels (`PaywallView.allPlans`), et le code note qu'Elite, Fondateur et les formules annuelles sont retirés de la vente. Si ces produits sont encore « en vente » dans App Store Connect, pensez à les retirer là aussi.
3. **« sans expiration »** des packs : retiré, je n'ai pas vérifié que les crédits n'expirent jamais.
4. **Face ID et mode hors-ligne :** retirés, faute de les trouver dans le code. À remettre seulement s'ils existent vraiment.
5. **« Photographiez une pièce » :** ajouté à votre demande ; je ne l'ai pas vu fonctionner dans les enregistrements.
6. **Noms :** « Essentiel » et « Signature » sont les noms affichés par Apple ; le code dit Starter et Premium.
7. Les autres langues de la fiche (5 autres) ont sans doute les mêmes anciens prix.
