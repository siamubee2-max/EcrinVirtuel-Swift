-- Migration 008 — Security hardening (007 defensive audit, 2026-06-19)
-- Applied to prod itjtshfzpknlzownpwte via MCP. Removes two over-permissive policies.
--
-- Findings closed:
--  • device_tryons had an ALL policy `USING(true) WITH CHECK(true)` → RLS effectively off;
--    any client could reset its own try_on_count / max_free_tryons (device free-trial bypass).
--  • storage.objects had a broad SELECT policy letting clients LIST every file in the
--    PUBLIC `tryon-temp` bucket → enumerate uploaded user face photos.

-- 1) device_tryons is a device-based quota: it must be managed server-side only.
--    RLS stays ENABLED with no policy => only service_role (Edge Function) can access it.
DROP POLICY IF EXISTS device_tryons_all ON public.device_tryons;

-- 2) Drop the bucket-listing policy. Direct object access via the public CDN URL
--    (used by the image-generation provider) is unaffected — only list() is removed.
DROP POLICY IF EXISTS "tryon-temp public read" ON storage.objects;
