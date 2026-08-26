-- Migration 010 — privatize tryon-temp (M1). Applied to prod 2026-06-21 via MCP,
-- AFTER tryon-generate v22 (signed URLs) was deployed and smoke-tested (real
-- generation succeeded on the private bucket). Closes the face-photo exposure window:
-- the bucket was publicly listable/fetchable; v22 now passes a 120s signed URL to Kie.ai.
update storage.buckets set public = false where id = 'tryon-temp';
