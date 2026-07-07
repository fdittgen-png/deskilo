# ADR 0002 — Supabase as the shared source of truth

**Status:** accepted · **Date:** 2026-07-07

## Context

Sparkilo is local-first with a narrow Supabase edge. DesKilo cannot be: reservations, check-ins, ledgers, and the confirmation protocol are inherently multi-user and need transactional, server-side conflict resolution (double-booking is the category's #1 failure mode).

## Decision

Supabase is the backend: Supabase Auth, RLS-protected Postgres as the source of truth for all shared state, and edge functions (or SQL functions) for the transactional operations — booking-conflict checks, atomic walk-up check-in, series expansion, statement generation. The client stays local-first for reads (Hive cache, offline floor plan/ledger viewing); writes require connectivity.

Supabase is open source and self-hostable, preserving the libre/no-lock-in promise for communities that want their own instance.

## Consequences

An RLS permission matrix (worker/admin/owner, per workspace) must be designed and security-audited like Sparkilo's `SUPABASE_RLS_MATRIX`. Conflict decisions never happen client-side against possibly-stale views. Whether the reference deployment is Supabase-hosted or self-hosted is an open operational decision and does not affect the schema.
