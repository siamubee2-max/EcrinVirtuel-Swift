-- Migration 011 — App Attest device key registry (M4). Applied to prod 2026-06-21 via MCP.
-- Stores one row per attested Apple App Attest key. Service-role only (Edge Function).
create table if not exists public.device_attest (
  key_id     text primary key,
  public_key text not null,          -- device public key (base64), extracted from attestation
  sign_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.device_attest enable row level security;
-- No policy: only the service_role (Edge Function) reads/writes this table.
