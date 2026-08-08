# L'Écrin Virtuel

Essayage virtuel de bijoux et de mode par IA, sur iOS — réalité augmentée, génération d'images IA et recommandations de looks selon la météo.

## Fonctionnalités

- **Essayage AR en temps réel** — bijoux positionnés en direct via ARKit et la caméra
- **Looks générés par IA** — mise en scène photoréaliste de tenues et bijoux (GPT Image / Gemini, cascade de fallback)
- **Recommandations météo** — suggestions de tenues adaptées à la météo et à la saison de l'utilisateur
- **Dressing & catalogue** — bibliothèque de vêtements et bijoux, moodboards, cadeaux à partager
- **Communauté & gamification** — défis, classements, badges, quêtes
- **Abonnement** — gestion des crédits et achats via RevenueCat/StoreKit

## Stack technique

| Composant | Techno |
|---|---|
| UI | SwiftUI, ARKit, RealityKit |
| Backend | Supabase (Postgres, Edge Functions, RLS) |
| IA génération d'images | GPT Image 2 / Gemini (cascade côté Edge Function) |
| Paiement / abonnement | RevenueCat, StoreKit |
| Localisation | Weather + CoreLocation |

## App Store

Disponible sur l'App Store : [ecrin.app](https://ecrin.app)

## Statut

Projet iOS natif en développement actif. Les clés API sensibles (OpenAI, Google, Kie) ne sont jamais embarquées dans l'app — elles vivent uniquement côté Supabase Edge Functions.
