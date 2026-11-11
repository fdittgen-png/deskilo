// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3742 — a business's own policy (its reminder rules, its document
// template, its billing and split rules) is a read like any other: when it
// could not be read, no default stands in for it, the failure is said at
// once (no automatic retries), and nothing is built on a guess. "Never saved"
// is an answer — the business gets the defaults; "could not be read" is not.
import 'package:deskilo/core/data/policy_read.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/money/presentation/screens/invoicing_wizard_screen.dart';
import 'package:deskilo/features/money/presentation/screens/repartition_wizard_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderBase;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

const _failed = 'This could not be loaded. Try again.';

/// The business's reminder rules cannot be read; counts the attempts.
class _RulesDown extends FakeMoneyRepository {
  int reads = 0;
  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async {
    reads++;
    throw StateError('the rules could not be read');
  }
}

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  test('never saved gives the defaults; could not be read gives the failure, '
      'at once and only once', () async {
    final saved = ProviderContainer(
      overrides: standardTestOverrides(money: FakeMoneyRepository()),
    );
    addTearDown(saved.dispose);
    expect(
      await saved.read(dunningRulesProvider.future),
      DunningRules.defaults,
      reason: 'a business that never saved its rules has the defaults',
    );

    final down = _RulesDown();
    final failing = ProviderContainer(
      overrides: standardTestOverrides(money: down),
    );
    addTearDown(failing.dispose);
    final sub = failing.listen(dunningRulesProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      failing.read(dunningRulesProvider.future),
      throwsStateError,
    );
    expect(
      failing.read(dunningRulesProvider).hasValue,
      isFalse,
      reason: 'no default stands in for an unread policy',
    );
    expect(down.reads, 1);
  });

  test('the four policy reads never retry on their own: the failure is said '
      'at once, with Try again', () {
    expect(noPolicyRetry(0, StateError('x')), isNull);
    for (final provider in <ProviderBase<Object?>>[
      dunningRulesProvider,
      invoicePdfTemplateProvider,
      billingRulesProvider,
      repartitionRuleProvider,
    ]) {
      expect(provider.retry, same(noPolicyRetry), reason: '$provider');
    }
  });

  testWidgets('an unread template is never printed as an empty one', (
    tester,
  ) async {
    Object? thrown;
    await tester.pumpWidget(
      _app(
        [
          ...standardTestOverrides(money: FakeMoneyRepository()),
          enabledFeaturesSyncProvider.overrideWithValue({
            WorkspaceFeature.invoicePdfTemplate,
          }),
          invoicePdfTemplateProvider.overrideWith(
            (ref) async => throw StateError('the template could not be read'),
          ),
        ],
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              try {
                invoicePdfTemplateFor(ref);
              } on Object catch (e) {
                thrown = e;
              }
            },
            child: const Text('print'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('print'));
    expect(thrown, isNotNull, reason: 'the guarded print says it failed');
    expect(thrown, isNot(isA<InvoicePdfTemplate>()));
  });

  testWidgets('unread billing rules: the wizard says so instead of '
      'suggesting a run', (tester) async {
    await tester.pumpWidget(
      _app([
        ...standardTestOverrides(money: FakeMoneyRepository()),
        billingRulesProvider.overrideWith(
          (ref) async =>
              throw StateError('the billing rules could not be read'),
        ),
      ], const InvoicingWizardScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_failed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unread split rule: the wizard waits and says it failed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        ...standardTestOverrides(money: FakeMoneyRepository()),
        repartitionRuleProvider.overrideWith(
          (ref) async => throw StateError('the split rule could not be read'),
        ),
      ], const RepartitionWizardScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('wizard-title')),
      'Internet',
    );
    await tester.enterText(find.byKey(const ValueKey('wizard-amount')), '100');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('could not be loaded'), findsWidgets);
    expect(find.byType(RepartitionMethod), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
