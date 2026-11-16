// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553 — the reader of what a business publishes: its kinds, its services
// (each price in its own currency with its tax word) and whether it takes
// inquiries; and the owner's read-only preview of them. A service in a
// shape this version cannot show is left out, never shown half; an unknown
// kind is not shown as a code.
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_offer_preview.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PublicWorkspace _card(Map<String, Object?> doc) =>
    PublicWorkspace('ws', 'https://a.example', 'k', {'name': 'A', ...doc});

Future<void> _preview(WidgetTester tester, PublicWorkspace offer) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PublicOfferPreview(offer: offer)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _line(WidgetTester tester, int i) => tester
    .widget<Text>(find.byKey(ValueKey('public-page-offer-service-$i')))
    .data!;

void main() {
  test('the reader takes kinds, services and the inquiries answer', () {
    final w = _card({
      'kinds': ['studio', 'coworking'],
      'services': [
        {
          'name': 'Yoga',
          'category': 'Classes',
          'duration_minutes': 60,
          'price_minor': 2500,
          'currency': 'EUR',
          'tax_treatment': 'included',
        },
        // A newer shape (no tax word this version knows): left out.
        {
          'name': 'Later',
          'price_minor': 1,
          'currency': 'EUR',
          'tax_treatment': 'mixed',
        },
      ],
      'takes_inquiries': false,
    });
    expect(w.kinds, ['studio', 'coworking']);
    expect(w.services.map((s) => s.name), ['Yoga']);
    expect(w.services.single.durationMinutes, 60);
    expect(w.takesInquiries, isFalse);
  });

  test('an installation that publishes none of it says nothing', () {
    final w = _card({});
    expect(w.kinds, isEmpty);
    expect(w.services, isEmpty);
    expect(w.takesInquiries, isNull);
  });

  testWidgets('the preview names each price with its tax word, in its own '
      'currency', (tester) async {
    await _preview(
      tester,
      _card({
        'kinds': ['practice', 'futurekind'],
        'services': [
          {
            'name': 'Massage',
            'duration_minutes': 60,
            'price_minor': 9500,
            'currency': 'CHF',
            'tax_treatment': 'none',
          },
          {
            'name': 'Desk',
            'price_minor': 3000,
            'currency': 'USD',
            'tax_treatment': 'excluded',
          },
          {
            'name': 'Coffee',
            'price_minor': 150,
            'currency': 'EUR',
            'tax_treatment': 'included',
          },
        ],
        'takes_inquiries': true,
      }),
    );
    expect(
      find.text('Kind: Practice'),
      findsOneWidget,
      reason: 'an unknown kind is not shown as a code',
    );
    expect(
      _line(tester, 0),
      allOf(
        startsWith('Massage · 60 min · '),
        contains('CHF'),
        endsWith(' · no tax'),
      ),
    );
    expect(
      _line(tester, 1),
      allOf(startsWith('Desk · '), endsWith(' · plus tax')),
    );
    expect(_line(tester, 2), endsWith(' · tax included'));
    expect(find.text('Visitors can write to you'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('public-page-offer-edit')),
      findsOneWidget,
    );
  });

  testWidgets('with no public service, it says how one gets there', (
    tester,
  ) async {
    await _preview(
      tester,
      _card({
        'kinds': ['coworking'],
        'services': [],
      }),
    );
    expect(
      find.byKey(const ValueKey('public-page-offer-none')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('public-page-offer-service-0')),
      findsNothing,
    );
  });
}
