// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1221 — the Features screen, organised by WHERE a feature shows up.
//
// It grouped by tier, which answers "should a space like mine have
// this" — a fair question, and not the one an owner arrives with. They
// arrive having seen something on a screen, or wanting something to
// appear on one, so the grouping is the place and the tier survives as
// a chip on the row.
//
// And the descriptions average 158 characters and run to 390, so shown
// whole they were prose you scrolled past rather than read.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/feature_surface_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features_screen_test.dart' show pumpFeatures;

void main() {
  group('the registry', () {
    test('every feature says where it shows up', () {
      // The field is required, so this cannot regress — the test is
      // here to say that is deliberate, and to catch a surface nobody
      // ever uses.
      final used = {for (final e in featureManifest.values) e.surface};
      expect(
        FeatureSurface.values.toSet().difference(used),
        isEmpty,
        reason: 'a surface with no features in it is a heading over '
            'nothing, and a name the reader has to decode for no reason',
      );
    });
  });

  group('the description', () {
    test('splits at the first sentence, and only when there is a rest', () {
      final split = splitFeatureDescription(
        'Monthly overview of bookings and closed days. Members see their '
        'own; admins see everyone.',
      );
      expect(split.lead, 'Monthly overview of bookings and closed days.');
      expect(split.rest, startsWith('Members see'));
    });

    test('a one-sentence description is left whole', () {
      const only = 'Members can export their data as one file.';
      expect(splitFeatureDescription(only).lead, only);
      expect(splitFeatureDescription(only).rest, isEmpty);
    });

    test('a decimal point is not a sentence end', () {
      const text = 'Charges 1.5 times the rate after 18:00 on weekdays.';
      expect(splitFeatureDescription(text).lead, text);
    });

    test('a tail too short to be worth a control stays in the lead', () {
      const text = 'Does a thing. Really.';
      expect(splitFeatureDescription(text).rest, isEmpty);
    });
  });

  group('the screen', () {
    testWidgets('groups by where the feature appears, not by tier',
        (tester) async {
      await pumpFeatures(tester);

      expect(find.byKey(const ValueKey('feature-surface-money')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('feature-surface-reserve')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('feature-tier-core')), findsNothing,
          reason: 'the tier stopped being the sorting key');
    });

    testWidgets('a heading says what that part of the app is for',
        (tester) async {
      await pumpFeatures(tester);
      expect(
        find.text('Statements, payments, invoices and what they are made of.'),
        findsOneWidget,
        reason: 'a group is a place, not a word',
      );
    });

    testWidgets('a long description shows its lead sentence and folds the '
        'rest away', (tester) async {
      await pumpFeatures(tester);
      // Price negotiations carries one of the longest descriptions.
      final more =
          find.byKey(const ValueKey('feature-more-priceNegotiations'));
      await tester.scrollUntilVisible(more, 200,
          scrollable: find.byType(Scrollable).last);
      expect(more, findsOneWidget);

      await tester.tap(find.descendant(of: more, matching: find.text('More')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: more, matching: find.text('Less')),
          findsOneWidget);
    });
  });
}
