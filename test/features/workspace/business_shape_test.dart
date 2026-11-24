// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4407 -- one BusinessShape says whether a business has places, sells services or is a shop. A coworking space that
// switches places off by hand reads as a business without places on every setup step, as a practice whose kind keeps
// them off does; the setup questions word themselves from the same value.
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/business_shape.dart';
import 'package:deskilo/features/workspace/domain/setup_recommendation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_question_group.dart';
import 'package:deskilo/features/workspace/providers/business_kind_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessShape _shape(Set<WorkspaceFeature> features, {bool kindOff = false, List<String> kinds = const ['coworking']}) =>
    BusinessShape.of(features: features, kindKeepsPlacesOff: kindOff, kinds: kinds);

void main() {
  group('the three sources, and which wins', () {
    test('places need the effective feature AND a kind that keeps them', () {
      expect(_shape({WorkspaceFeature.placeBooking}).places, isTrue);
      expect(_shape({}).places, isFalse, reason: 'switched off by hand: a coworking space reads as without places');
      expect(_shape({WorkspaceFeature.placeBooking}, kindOff: true).places, isFalse, reason: 'the kind keeps them off');
    });

    test('services follow the effective feature; a shop is any kind of the business', () {
      expect(_shape({WorkspaceFeature.services}).services, isTrue);
      expect(_shape({}).services, isFalse);
      expect(_shape({}, kinds: const ['coworking', 'shop']).shop, isTrue);
      expect(_shape({}, kinds: const ['practice']).shop, isFalse);
    });
  });

  test('the provider reads the shape from the features, the kind and the profile', () async {
    final container = ProviderContainer(
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.placeBooking, WorkspaceFeature.services}),
        businessKindsProvider.overrideWith((ref) async => const []),
        businessProfileProvider.overrideWith((ref) async => const BusinessProfile(kind: 'shop')),
      ],
    );
    addTearDown(container.dispose);
    await container.read(businessProfileProvider.future);
    final shape = container.read(businessShapeProvider);
    expect((shape.places, shape.services, shape.shop), (true, true, true));
  });

  group('the setup questions word themselves from it', () {
    Future<void> pump(WidgetTester tester, Set<WorkspaceFeature> features) async {
      final controller = ExpansibleController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            enabledFeaturesSyncProvider.overrideWithValue(features),
            businessKindsProvider.overrideWith((ref) async => const []),
            businessProfileProvider.overrideWith((ref) async => const BusinessProfile(kind: 'coworking')),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SetupQuestionGroup(
                  id: 'bookings',
                  title: 'Bookings',
                  questions: const ['several_rooms_or_sites'],
                  answers: const SetupAnswers(),
                  unknown: const {},
                  busy: false,
                  open: true,
                  controller: controller,
                  focusOf: (_) => FocusNode(),
                  onAnswer: (q, {required yes, unknown = false}) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a coworking space with places switched off by hand reads the no-places question', (tester) async {
      await pump(tester, {});
      expect(find.text('Several sites or addresses'), findsOneWidget);
    });

    testWidgets('with places on it reads the place question', (tester) async {
      await pump(tester, {WorkspaceFeature.placeBooking});
      expect(find.text('Several sites or addresses'), findsNothing);
    });
  });
}
