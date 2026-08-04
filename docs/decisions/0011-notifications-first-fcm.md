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

Firebase Cloud Messaging becomes the primary push transport on Android,
iOS (APNs), web and macOS. UnifiedPush remains as an automatic fallback
where Firebase is unconfigured, but is no longer the reason to keep the
dependency tree Google-free: the no-GMS CI audits are removed, the
F-Droid flavor/recipe plans are cancelled, and ADR 0003 is superseded.
The 0012 privacy doctrine stands: pushed payloads carry a kind and no
personal data; background notifications show generic per-kind text.

## Consequences

- One-time owner setup (Firebase project, `flutterfire configure`,
  APNs key, `FCM_SERVICE_ACCOUNT` secret) — docs/guides/push-setup.md.
- Play-store users get push with zero user-side setup; the app-icon
  badge counter rides the same pipeline.
- Self-hosters who reject Google can still run UnifiedPush: keep the
  firebase_options stub and the fallback engages.
