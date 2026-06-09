-- Migration 006 — Remove author_email from community_posts (PII fix)
--
-- author_email was stored in a public table readable by all authenticated users,
-- exposing the email address of post authors to other users (PII violation).
-- The author's identity is already represented by user_id (foreign key to auth.users)
-- and author_display_name (non-sensitive).
--
-- After this migration the iOS app must NOT include author_email in SELECT or INSERT.
-- See: SupabaseCommunityPostRow, SupabaseCommunityPostInsert in SupabaseService.swift

ALTER TABLE community_posts DROP COLUMN IF EXISTS author_email;
