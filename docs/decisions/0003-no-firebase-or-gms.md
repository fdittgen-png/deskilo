# ADR 0003 — No Firebase, no Google Play Services

**Status:** accepted · **Date:** 2026-07-07

## Context

DesKilo targets F-Droid, where Google proprietary dependencies are disqualifying, and the project's privacy promise excludes third-party tracking. Sparkilo already proved the pattern with a dedicated GMS-free `fdroid` product flavor and an audit script.

## Decision

No Firebase, no Google Play Services, no third-party analytics/tracking in any flavor. Push notifications use local scheduling plus UnifiedPush/ntfy for the F-Droid flavor. QR scanning uses libre `flutter_zxing`. A `fdroid` product flavor plus an `audit_no_gms.sh`-style script guard this in CI.

## Consequences

Some conveniences (FCM, Play in-app review, ML Kit) are unavailable or need libre substitutes. Accepted — this is a founding constraint, identical to Sparkilo's ADR of the same name.
