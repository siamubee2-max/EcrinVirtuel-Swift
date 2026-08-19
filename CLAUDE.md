# L'Écrin Virtuel — Swift (iOS)

## Build & Verification

**ALWAYS use Xcode (`xcodebuild`). NEVER `swift build`.**

```bash
xcodebuild build -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
```

- Project: `EcrinVirtuel.xcodeproj` · Schemes: `EcrinVirtuel`, `RevenueCatUI`
- Targets: `EcrinVirtuel`, `EcrinVirtuelTests`
- Check result with `grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"` — `xcodebuild ... | tail` masks the real exit code.

## Backend (Supabase)

- **CANONICAL project: `itjtshfzpknlzownpwte`** (Dashboard "lecrin-replit", `https://itjtshfzpknlzownpwte.supabase.co`). Confirmed by `HANDOFF.md` (1 June 2026). This is the live Écrin Virtuel backend.
- **Do NOT point the app at `amafgweelzayrjzemdtq`** ("les crocs malins" — a different/shared product DB). The HANDOFF explicitly corrected a prior mis-pointing to that project.
- Config in `Secrets.xcconfig` (gitignored): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_IOS_KEY`. URL uses xcconfig escape `https:/$()/...` (`//` is a comment).
- Catalogue tables on itjtshfzp: `jewelry` (39 MONI'ATTITUDE rows), `clothing_catalog` (95 rows). Both RLS + public SELECT, anon-readable. Schemas match the Swift `SupabaseJewelry` / `ClothingGender` decoders. Catalog image_url assets are hosted on `amafgweelzayrjzemdtq` public storage (cross-project, public buckets) — migrate to itjtshfzp storage long-term.
- `body_parts` (47 mannequin rows, migrated 2 July 2026 from amafgweelzayrjzemdtq via migration `create_body_parts_mannequins`): RLS, global rows (`user_id IS NULL`) anon-readable, user rows owner-only. Consumed by `BodyModelService`. Image URLs are cross-project (amaf public storage + legacy `d2xsxph8kpxj0f.cloudfront.net`) — migrate to itjtshfzp storage long-term.
- `tryon-generate` **v21** = Kie.ai cascade (KIE_API_KEY): standard → `gpt-image-2-image-to-image` (9:16 native), premium → `nano-banana-pro`; fallbacks nano-banana-2 → flux-kontext → gpt4o-image → Gemini 2.0 → OpenAI gpt-image-1. Founder bypass: `siamubee2@gmail.com`, `monia.valenza@gmail.com` (unlimited, no quota decrement).
- Other edge functions: `credits-check`, `credit-generations`, `device-tryon`, `revenuecat-webhook`, `delete-user-account`, `try-on`.
- **Anonymous sign-ins ENABLED** (2 July 2026) on itjtshfzp: onboarding "ESSAYER MAINTENANT" silently calls `signInAnonymously()` (`GenerationAuthGate.ensureSession()`), honouring "3 essais offerts · Aucune carte requise". Trigger `handle_new_user` is anonymous-safe (placeholder email/username) and seeds BOTH `users` (3 jewelry credits, display) and `user_quotas` (3, consumed by `consume_credits` RPC in tryon-generate). RootView restores existing sessions at launch. Known follow-up: Apple Sign-In after anonymous creates a NEW user (no identity linking) — anonymous credits are not migrated.
- AI secrets (KIE_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY, FAL_API_KEY) live ONLY in Supabase Edge Function secrets — never in the IPA / source. Confirm `KIE_API_KEY` present on itjtshfzp (Dashboard → Functions → Secrets).

## App Store compliance (audit 3 July 2026)

- **UGC moderation (guideline 1.2)**: Community feed has per-post "…" menu → report (5 reasons) + block author, wired to `CommunityViewModel.report/blockAuthor` and `SupabaseService.reportPost` (table `post_reports`). Feed renders `visiblePosts` (excludes blocked/reported). Terms `terms.html` §5 states zero-tolerance policy. NOTE: sample-seed posts aren't in `community_posts`, so the FK-guarded server insert only persists for real user posts — UI masking always works.
- **Info.plist**: `NSPhotoLibraryAddUsageDescription` added (app saves try-ons via `PHPhotoLibrary.addOnly`). `ITSAppUsesNonExemptEncryption=false`. Privacy manifest `Sources/Resources/PrivacyInfo.xcprivacy` (tracking=false).
- **Legal URLs**: privacy live at `inferencevision.store/ecrin/privacy(.html)`. `terms` was 404 — canonical `terms.html` staged in `web/public/ecrin/` and the site deploy dirs (`inferencevision-site/deploy-ready-hubv3/ecrin/`, `site/ecrin/`). **ACTION REQUIRED: redeploy inferencevision.store so `/ecrin/terms` resolves before submission.**
- **Paywall (3.1.2)**: PaywallView + CreditsPackView show auto-renew disclosure + CGU/Confidentialité links + "Restaurer mes achats".
- **Weather attribution**: Open-Meteo credit shown in `LookDuJourCard` (data source disclosure).
- **DEV skip-login** in `LoginView` is `#if DEBUG` only (stripped from Release).

## Conventions

- Logging: `os.Logger` (subsystem `com.ecrin.jewelry`, category per feature). No `print()` in production code.
- Try-on / result images: vertical **9:16** (`aspectRatio(9.0/16.0, contentMode: .fit)`).
- Communicate in French; code/comments in English.
