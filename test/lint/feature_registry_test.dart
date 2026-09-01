// SPDX-License-Identifier: 0BSD
//
// Feature-management completeness (#502) — the LIFETIME rule of this
// project: every user-facing functionality ships behind a
// [WorkspaceFeature] flag, wired end to end. Concretely, a new
// functionality lands with:
//   1. a WorkspaceFeature enum value (compile-time exhaustive switches
//      then FORCE the name + description wiring),
//   2. a featureManifest entry (defaultOn + requires),
//   3. featureXxx / featureXxxDesc l10n keys in all five locales,
//   4. `features.contains(...)` gates on its UI surfaces,
//   5. this pin bumped — the number changing in review IS the check
//      that the author thought about feature management.
// See docs/AGENT_RULES.md ("Feature management").
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/feature_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// 27 pre-#502 + documents (#500) + dunning + memberReports +
/// deletionRequests (#502).
// 30→31 (2026-08-06): #513 roleManagement.
// 31→32 (2026-08-11): #534 vatDeclarations (requires invoicing).
// 32→33 (2026-08-11): #544 vatManagement (rates editor + rate pickers;
// vatDeclarations re-parented under it).
// 33→34 (2026-08-14): #568 einvoiceCustomerDelivery (second send leg).
// 34→35 (2026-08-22): #587 planObjectDelete (delete plan objects past
// reservations reference; audit substitution text).
// 35→36 (2026-08-23): #598 notificationGrouping (regroup the feed by
// type, day or member; requires eventsTab).
// 36→37 (2026-08-23): #600 bookingPolicies (owner-configurable booking
// behavior matrix: past bookings, grid-vs-hours, admin check-out).
// 37→39 (2026-08-23): #604 nfcSeatTags (chair-tag config + resolution,
// #585 retro-flagged) and qrBadges (QR badge issuance beside nfcBadges).
// 39→40 (2026-08-23): #606 formHelpHints (dismissible contextual help
// hints deep-linking into the guide; Settings restores dismissed ones).
// 40→41 (2026-08-23): #611 uiAnimations (the motion pass — purposeful
// animations app-wide; OFF = instant everything, reduced motion wins).
// 41→42 (2026-08-24): #616 kioskMemberPhotos (receipt shows the
// member's profile photo; child of kioskMode).
// 43→44 (2026-08-27): #662 badgeSignIn (sign in by scanning a badge,
//   then a PIN; under nfcBadges — the login button must disappear with
//   badge issuance, or it offers a credential nobody can hold).
// 42→43 (2026-08-24): #620 planMemberPhotos (occupant photos on the
// Plan tab and Reserve hub maps; standalone, kiosk not required).
// 44→45 (2026-08-28): #711 regionalFormats (member format locale, clock,
// time-zone mode; Settings → Region & formats).
// 45→48 (2026-08-29): #718 calendarHub, #719 dataAccessLog + memberDataExport.
// 48→49 (2026-08-29): #720 financeFaces.
// 49→50 (2026-08-29): #726 paymentReminders.
// 50→52 (2026-08-29): #731 supplyExpenses, #732 validationScopes.
// 52→53 (2026-08-30): #739 priceNegotiations.
// 53→54 (2026-08-31): #767 scheduledExpenses.
// 54→55 (2026-09-01): #793 uniqueMonograms — avatar initials that name
// one member instead of repeating across everyone who shares a letter.
// 55→56 (2026-09-01): #798 messageGestures — swipe right to quote, left
// to take back an unread message.
const int _expectedFeatureCount = 56;

void main() {
  test('every functionality is registered — the pin', () {
    expect(
      WorkspaceFeature.values.length,
      _expectedFeatureCount,
      reason: 'WorkspaceFeature has ${WorkspaceFeature.values.length} '
          'entries, the pin says $_expectedFeatureCount. New '
          'functionality? Add its flag (enum + manifest + names + l10n '
          '+ UI gates) and bump the pin. Removed one? Walk the manifest '
          'and the gates first.',
    );
  });

  test('every feature has a manifest entry (defaultOn/requires)', () {
    for (final feature in WorkspaceFeature.values) {
      expect(
        featureManifest[feature],
        isNotNull,
        reason: '${feature.name} is missing from featureManifest — the '
            'Features screen would not offer it and enabledFeatures '
            'could not default it.',
      );
    }
  });

  test('every feature has a human name (fallback wired)', () {
    for (final feature in WorkspaceFeature.values) {
      expect(
        featureName(null, feature).trim(),
        isNotEmpty,
        reason: '${feature.name} has no name in feature_names.dart',
      );
    }
  });

  test('requires-chains stay acyclic and point at registered features',
      () {
    for (final entry in featureManifest.entries) {
      final seen = <WorkspaceFeature>{entry.key};
      var current = entry.value.requires;
      while (current != null) {
        expect(seen.add(current), isTrue,
            reason: 'requires cycle through ${current.name}');
        expect(featureManifest[current], isNotNull,
            reason:
                '${entry.key.name} requires unregistered ${current.name}');
        current = featureManifest[current]?.requires;
      }
    }
  });
}
