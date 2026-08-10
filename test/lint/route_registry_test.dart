// SPDX-License-Identifier: 0BSD
//
// Route-registry lint: a new route cannot be added silently.
//
// Every feature-linked surface must be gated at TWO layers — the entry
// point checks `enabledFeaturesSync`, and the route guards with a
// `featureEnabled(...)` redirect so deep links bounce too. The second
// layer is the one people forget, because the screen "works" without it.
// Pinning the route count turns adding a route into a deliberate act
// that walks through the checklist below, instead of a silent line in a
// thousand-line router.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RATCHET-ADJACENT PIN. Changing this number is fine — that is the
/// point: it makes you read this comment first.
///
/// Adding a route? The checklist (Implementation.md, feature-flags
/// section):
///  1. If the surface belongs to a WorkspaceFeature: `featureEnabled`
///     redirect on the route AND the hidden entry point.
///  2. A widget test for the hidden entry and the bounced deep link
///     (see test/features/profile/settings_sections_test.dart).
///  3. The Features screen itself stays ungated — always reachable.
// 35→36 (2026-08-05): #486 /payment-methods (owner-gated redirect).
// 36→37 (2026-08-05): #500 /documents (feature-gated redirect).
// 37→38 (2026-08-06): #513 /roles (feature-gated redirect).
// 38→41 (2026-08-10): 0106 WhatsApp message mirror deep links —
// /msg/:id (feature-gated), /res/:id, /space/:kind/:id.
const int _expectedRouteCount = 41;

void main() {
  test('router carries exactly $_expectedRouteCount GoRoutes', () {
    final source = File('lib/app/router.dart').readAsStringSync();
    final count = RegExp(r'GoRoute\(').allMatches(source).length;
    expect(
      count,
      _expectedRouteCount,
      reason: 'lib/app/router.dart has $count GoRoutes, the pin says '
          '$_expectedRouteCount. If you added or removed a route on '
          'purpose, update the pin — after walking the gating checklist '
          'in this file\'s header. A route without its featureEnabled '
          'redirect is reachable by deep link with the feature off.',
    );
  });
}
