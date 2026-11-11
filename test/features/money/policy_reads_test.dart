// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3742 — a business's own policy (its reminder rules, its document
// template, its billing and split rules) is a read like any other: when it
// could not be read, no default stands in for it, the failure is said at
// once (no automatic retries), and nothing is built on a guess. "Never saved"
// is an answer — the business gets the defaults; "could not be read" is not.
import 'dart:async';

import 'package:deskilo/core/state/policy_read.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/money/presentation/invoice_followup_actions.dart';
import 'package:deskilo/features/money/presentation/invoice_pdf_actions.dart';
import 'package:deskilo/features/money/presentation/screens/invoicing_wizard_screen.dart';
import 'package:deskilo/features/money/presentation/screens/repartition_wizard_screen.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_template_sheet.dart';
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
import '../../helpers/test_workspace_context.dart';

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

  // #3742 — the reads above are sticky without retries: an action asks a
  // remembered failure again and awaits a read still running.
  Future<void> act(
    WidgetTester tester,
    List<Override> overrides,
    Future<void> Function(BuildContext context, WidgetRef ref) action,
  ) async {
    await tester.pumpWidget(
      _app(
        overrides,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () => action(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('(a) the first print of a session waits for the template it '
      'never read, and prints without a message', (tester) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-06',
    );
    await act(
      tester,
      [...standardTestOverrides(money: money), testReadyWorkspaceContext()],
      (context, ref) => quickViewInvoice(context, ref, money.invoices.single),
    );
    await tapGo(tester);
    expect(find.text(_failed), findsNothing);
    expect(find.byKey(const ValueKey('report-quick-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('(b) a template read that fails once says so; Retry prints', (
    tester,
  ) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-06',
    );
    var reads = 0;
    await act(tester, [
      ...standardTestOverrides(money: money),
      testReadyWorkspaceContext(),
      invoicePdfTemplateProvider.overrideWith((ref) async {
        if (reads++ == 0) throw StateError('the template could not be read');
        return InvoicePdfTemplate.empty;
      }),
    ], (context, ref) => quickViewInvoice(context, ref, money.invoices.single));
    await tapGo(tester);
    expect(find.text(_failed), findsOneWidget);
    expect(find.byKey(const ValueKey('report-quick-preview')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('print-read-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('report-quick-preview')), findsOneWidget);
    expect(reads, 2, reason: 'the remembered failure was asked again');
  });

  testWidgets('(c) reminder rules that fail once: Remind says so, the second '
      'tap sends', (tester) async {
    final money = _Reminders();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-06',
    );
    var reads = 0;
    await act(tester, [
      ...standardTestOverrides(money: money),
      testReadyWorkspaceContext(),
      dunningRulesProvider.overrideWith((ref) async {
        if (reads++ == 0) throw StateError('the rules could not be read');
        return DunningRules
            .defaults; // empty-ok: never saved, the business's own answer
      }),
    ], (context, ref) => remindInvoice(context, ref, money.invoices.single));
    await tapGo(tester);
    expect(find.text(_failed), findsOneWidget);
    expect(money.reminded, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tapGo(tester);
    expect(money.reminded, [
      money.invoices.single.id,
    ], reason: 'the second tap reads the rules again and sends');
  });

  testWidgets('(d) billing rules that fail once: the wizard says so; opened '
      'again it suggests from the rules', (tester) async {
    var reads = 0;
    final overrides = [
      ...standardTestOverrides(money: FakeMoneyRepository()),
      billingRulesProvider.overrideWith((ref) async {
        if (reads++ == 0) {
          throw StateError('the billing rules could not be read');
        }
        return const BillingRules();
      }),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    Widget wizard() => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoicingWizardScreen(),
      ),
    );
    await tester.pumpWidget(wizard());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_failed), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(wizard());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_failed), findsNothing);
    expect(reads, 2, reason: 'opened again, the rules are read again');
  });

  testWidgets('(e) the template editor waits for the rules, then says they '
      'failed, with Try again — never an exception', (tester) async {
    final rules = Completer<DunningRules>();
    await tester.pumpWidget(
      _app(
        [
          ...standardTestOverrides(money: FakeMoneyRepository()),
          enabledFeaturesSyncProvider.overrideWithValue({
            WorkspaceFeature.dunning,
          }),
          dunningRulesProvider.overrideWith((ref) => rules.future),
        ],
        const Scaffold(
          body: ReportTemplateEditor(initial: InvoicePdfTemplate.empty),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    rules.completeError(StateError('the rules could not be read'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Counts the reminders sent.
class _Reminders extends FakeMoneyRepository {
  final reminded = <String>[];
  @override
  Future<void> remindInvoice(String invoiceId) async {
    reminded.add(invoiceId);
    return super.remindInvoice(invoiceId);
  }
}
