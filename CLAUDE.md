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

- **CANONICAL project: `vffafgzlsmfecqejoytw`** (`https://vffafgzlsmfecqejoytw.supabase.co`, account sabrina930212@gmail.com, org `qdneeeodnfxspmjdkxtv`, eu-north-1). Restored 17 Aug 2026 from the 10 Aug backup of the former project.
- **Former projects are DEAD — never point the app at them**: `itjtshfzpknlzownpwte` ("lecrin-replit") and `amafgweelzayrjzemdtq` ("les crocs malins") sit in an old org (`akkfxbpatifhedlsfmgv`) paused behind unpaid invoices. Catalog `image_url` values still reference `amafgweelzayrjzemdtq` public storage (images broken until that project is revived or assets are re-uploaded and URLs rewritten).
- Config in `Secrets.xcconfig` (gitignored): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_IOS_KEY`. URL uses xcconfig escape `https:/$()/...` (`//` is a comment).
- Catalogue tables restored: `jewelry` (39 MONI'ATTITUDE rows), `clothing_catalog` (95 rows), `body_parts` (47 mannequins). RLS + public SELECT, anon-readable. `public.users.id` is varchar = `auth.uid()::text`; `users.auth_id` (uuid, added in `swift_native_tables_adapted`) is what `resolveUsersRowID` queries.
- Edge functions (all 5 versioned in `supabase/functions/` — keep them in the repo): `tryon-generate` (fal.ai cascade: standard → `fal-ai/nano-banana-2/edit` 9:16, premium → `fal-ai/gemini-3-pro-image-preview/edit` (NB Pro); fallbacks flux-pro/kontext → Gemini 3.1 Flash Image direct → OpenAI gpt-image-1; founder bypass `siamubee2@gmail.com` / `monia.valenza@gmail.com`), `credit-generations` (consommables IAP, grille du 31/08/2026 : spark=10/eclat=40/diamant=140 crédits — `VALID_PACKS` fait foi, jamais le client ; idempotent via `credit_transactions`), `delete-user-account`, `styliste-chat` (OpenAI → Gemini), `revenuecat-webhook` (abonnements : starter=25/premium=60/elite=100 crédits/mois à chaque renouvellement ; requires `RC_WEBHOOK_SECRET`, verify_jwt off).
- Storage buckets: `community-posts` (public), `tryon-temp` (public, transient uploads for Kie), `tryon-results`, `gift-previews` (private).
- AI secrets (FAL_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY, RC_WEBHOOK_SECRET) live ONLY in Supabase Edge Function secrets — never in the IPA / source. They must be re-entered on the new project (Dashboard → Functions → Secrets).

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
