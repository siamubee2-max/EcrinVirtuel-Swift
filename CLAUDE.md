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
- `tryon-generate` **v21** = Kie.ai cascade (KIE_API_KEY): standard → `gpt-image-2-image-to-image` (9:16 native), premium → `nano-banana-pro`; fallbacks nano-banana-2 → flux-kontext → gpt4o-image → Gemini 2.0 → OpenAI gpt-image-1. Founder bypass: `siamubee2@gmail.com`, `monia.valenza@gmail.com` (unlimited, no quota decrement).
- Other edge functions: `credits-check`, `credit-generations`, `device-tryon`, `revenuecat-webhook`, `delete-user-account`, `try-on`.
- AI secrets (KIE_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY, FAL_API_KEY) live ONLY in Supabase Edge Function secrets — never in the IPA / source. Confirm `KIE_API_KEY` present on itjtshfzp (Dashboard → Functions → Secrets).

## Conventions

- Logging: `os.Logger` (subsystem `com.ecrin.jewelry`, category per feature). No `print()` in production code.
- Try-on / result images: vertical **9:16** (`aspectRatio(9.0/16.0, contentMode: .fit)`).
- Communicate in French; code/comments in English.
