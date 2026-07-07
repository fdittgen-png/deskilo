# ADR 0007 — Full translatability; English canonical + FR/DE/ES/IT at launch

**Status:** accepted · **Date:** 2026-07-07

## Context

The owner requires the app to be fully multilanguage. Sparkilo's ARB fragment pipeline, key-parity CI gate, and no-hardcoded-strings lint are proven at 23 locales.

## Decision

Every user-facing string goes through ARB / `AppLocalizations` (HARD RULE — lint-enforced, ratchet-to-zero baseline). **English (`en`) is the default and canonical locale**; **French, German, Spanish, Italian** ship at launch as maintained translations — every new key lands in all five in the same PR. The fragment-based ARB pipeline and key-parity test are adopted from Sparkilo so additional locales can be fanned out later. User-generated content (workspace names, notes) is not translated.

## Consequences

Slightly higher per-PR cost (five translations per key) in exchange for zero retrofit cost and an F-Droid/store listing that can localize via fastlane metadata per locale.
