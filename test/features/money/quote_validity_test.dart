// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4291 -- how long a quote stays valid is the business's own setting. The
// value reads the two registry settings (the registry default until the
// business sets them), the editor offers the business's default end, and the
// Demo's quotes refuse what the business's longest validity refuses: the same
// two numbers `save_customer_quote_draft_v1` reads.
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/core/settings/active_settings.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/ui/date_field.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/quote_validity.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/screens/customer_quote_editor_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/money/providers/customer_quote_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _definition(String key, int fallback, int max) => {
  'key': key,
  'type': 'int',
  'default_value': fallback,
  'min': 1,
  'max': max,
  'unit': 'days',
  'group_key': 'billing',
  'scopes': ['platform', 'workspace'],
  'edit_permission': 'workspaceSettings',
  'floor_value': null,
  'editable': true,
  'choices': null,
  'source': 'test',
  'note': '',
};

SettingsSet _settings({required int standard, required int longest}) =>
    SettingsSet.parse([
      {
        ..._definition('quotes.default_validity_days', 30, 365),
        'value': standard,
        'origin': 'workspace',
      },
      {
        ..._definition('quotes.max_validity_days', 365, 1825),
        'value': longest,
        'origin': 'workspace',
      },
    ]);

const _line = StandaloneLine(
  description: 'Consulting',
  quantity: '1',
  unitCode: 'hour',
  unitLabel: 'h',
  unitPrice: '100',
);

void main() {
  group('QuoteValidity', () {
    test('a business that sets nothing has the registry defaults: 30 and 365 '
        'days', () {
      const none = QuoteValidity();

      expect(none.defaultDays, SettingDefaults.quotesDefaultValidityDays);
      expect(none.maxDays, SettingDefaults.quotesMaxValidityDays);
      expect(SettingDefaults.quotesDefaultValidityDays, 30);
      expect(SettingDefaults.quotesMaxValidityDays, 365);
      expect(QuoteValidity.fromSettings(null).defaultDays, 30);
    });

    test('the business\'s own two settings are read', () {
      final own = QuoteValidity.fromSettings(
        _settings(standard: 14, longest: 60),
      );

      expect(own.defaultDays, 14);
      expect(own.maxDays, 60);
      final on = DateTime(2026, 3);
      expect(own.defaultEnd(on), DateTime(2026, 3, 15));
      expect(own.allows(on, DateTime(2026, 4, 30)), isTrue, reason: '60 days');
      expect(own.allows(on, DateTime(2026, 5)), isFalse, reason: '61 days');
      expect(own.allows(on, DateTime(2026, 2, 28)), isFalse, reason: 'before');
    });

    test('a default beyond the longest validity is the longest', () {
      const own = QuoteValidity(defaultDays: 90, maxDays: 60);

      expect(own.defaultEnd(DateTime(2026, 3)), DateTime(2026, 4, 30));
    });
  });

  group('the Demo\'s quotes', () {
    FakeCustomerQuoteRepository quotes(QuoteValidity validity) =>
        FakeCustomerQuoteRepository(clock: () => DateTime(2026, 3))
          ..validity = () => validity;

    QuoteDraftInput draft({DateTime? until}) => QuoteDraftInput(
      subjectId: 's-1',
      issuedOn: DateTime(2026, 3),
      validUntil: until,
      lines: const [_line],
    );

    test(
      'a draft with no end is valid for the business\'s default days',
      () async {
        final repo = quotes(const QuoteValidity(defaultDays: 14, maxDays: 60));

        await repo.saveDraft('ws', input: draft());

        final saved = (await repo.quotes('ws')).single.draft!;
        expect(saved.validUntil, DateTime(2026, 3, 15));
      },
    );

    test('the longest validity is accepted and one day more is refused, as '
        'the server does', () async {
      final repo = quotes(const QuoteValidity(defaultDays: 14, maxDays: 60));

      await repo.saveDraft('ws', input: draft(until: DateTime(2026, 4, 30)));
      await expectLater(
        repo.saveDraft('ws', input: draft(until: DateTime(2026, 5))),
        throwsA(
          isA<QuoteRefusal>().having((r) => r.missing, 'missing', [
            'valid_until',
          ]),
        ),
      );
    });

    test('a business that sets nothing keeps today\'s: 30 days by default and '
        '365 at most', () async {
      final repo = quotes(const QuoteValidity());

      await repo.saveDraft('ws', input: draft());
      await repo.saveDraft('ws', input: draft(until: DateTime(2027, 3)));
      await expectLater(
        repo.saveDraft('ws', input: draft(until: DateTime(2027, 3, 2))),
        throwsA(isA<QuoteRefusal>()),
      );
      final first = (await repo.quotes('ws')).last.draft!;
      expect(first.validUntil, DateTime(2026, 3, 31));
    });
  });

  testWidgets('the editor offers the business\'s own default end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final quotes = FakeCustomerQuoteRepository(clock: () => DateTime(2026, 3));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CustomerQuoteEditorScreen(quoteId: 'new'),
        ),
      ],
    );
    await pumpApp(
      tester,
      null,
      router: router,
      overrides: [
        ...standardTestOverrides(),
        customerQuoteRepositoryProvider.overrideWithValue(quotes),
        billingCustomerRepositoryProvider.overrideWithValue(
          FakeBillingCustomerRepository(),
        ),
        myPermissionsProvider.overrideWithValue(const {
          WorkspacePermission.issueInvoices,
        }),
        activeSettingsProvider.overrideWithValue(
          _settings(standard: 14, longest: 60),
        ),
      ],
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final today = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(clockProvider).now();
    final on = DateTime(today.year, today.month, today.day);

    final end = tester
        .widget<AppDateField>(find.byKey(const ValueKey('quote-valid-until')))
        .value;

    expect(end, isNotNull);
    expect(
      DateTime(end!.year, end.month, end.day),
      addCalendarDays(on, 14),
      reason: 'the business\'s 14, not 30',
    );
    expect(
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(quoteValidityProvider)
          .maxDays,
      60,
    );
  });
}
