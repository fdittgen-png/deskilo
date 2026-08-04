# ADR 0011 — Notifications first: FCM, F-Droid dropped

**Status:** accepted · **Date:** 2026-08-04

## Context

The app relies heavily on notifications (confirmations, overrules,
check-in reminders). ADR 0003 banned Google services, which forced
UnifiedPush — requiring every user to install and understand a
distributor app. Field reality after months of dogfooding: zero devices
ever registered a push endpoint. The owner ruled: notifications are
first priority; drop the F-Droid support.

## Decision

Firebase Cloud Messaging becomes the ONLY push transport on Android,
iOS (APNs), web and macOS (#428 removed the UnifiedPush fallback with
the rest of the F-Droid support). The no-GMS CI audits are removed, the
F-Droid flavor/recipe plans are cancelled, and ADR 0003 is superseded.
The 0012 privacy doctrine stands: pushed payloads carry a kind and no
personal data; background notifications show generic per-kind text.

## Consequences

- One-time owner setup (Firebase project, `flutterfire configure`,
  APNs key, `FCM_SERVICE_ACCOUNT` secret) — docs/guides/push-setup.md.
- Play-store users get push with zero user-side setup; the app-icon
  badge counter rides the same pipeline.
- Self-hosters must configure their own Firebase project (the stub
  pattern makes an unconfigured build local-notifications-only, never
  broken).
