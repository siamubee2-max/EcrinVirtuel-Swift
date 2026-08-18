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
- Edge functions (all 5 versioned in `supabase/functions/` — keep them in the repo): `tryon-generate` (Kie cascade: standard → `gpt-image-2-image-to-image` 9:16, premium → `nano-banana-pro`; fallbacks nano-banana-2 → flux-kontext → gpt4o-image → Gemini 2.0 → OpenAI gpt-image-1; founder bypass `siamubee2@gmail.com` / `monia.valenza@gmail.com`), `credit-generations` (starter=15/premium=40/elite=100, idempotent via `credit_transactions`), `delete-user-account`, `styliste-chat` (OpenAI → Gemini), `revenuecat-webhook` (requires `RC_WEBHOOK_SECRET`, verify_jwt off).
- Storage buckets: `community-posts` (public), `tryon-temp` (public, transient uploads for Kie), `tryon-results`, `gift-previews` (private).
- AI secrets (KIE_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY, RC_WEBHOOK_SECRET) live ONLY in Supabase Edge Function secrets — never in the IPA / source. They must be re-entered on the new project (Dashboard → Functions → Secrets).

## Conventions

- Logging: `os.Logger` (subsystem `com.ecrin.jewelry`, category per feature). No `print()` in production code.
- Try-on / result images: vertical **9:16** (`aspectRatio(9.0/16.0, contentMode: .fit)`).
- Communicate in French; code/comments in English.
