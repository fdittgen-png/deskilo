// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403 -- an action that states the workspace's own tax reference does not
// run on a guess and does not go silent: with the workspace context not ready
// a tap answers with a snack (or, for a preview, no live data), and a guarded
// action that meets the typed refusal answers the same way.
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/core/trace/workspace_context_not_ready.dart';
import 'package:deskilo/features/money/presentation/invoice_pdf_actions.dart';
import 'package:deskilo/features/money/presentation/invoice_proforma.dart';
import 'package:deskilo/features/money/presentation/recapitulative_actions.dart';
import 'package:deskilo/features/money/presentation/vat_report_actions.dart';
import 'package:deskilo/features/money/presentation/widgets/template_live_data.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/providers/operation_context_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

const _said = 'The workspace is still loading its tax settings';

/// A button that runs [action] with a context and ref, under a world whose
/// workspace context is not ready.
Future<FakeMoneyRepository> _pump(
  WidgetTester tester,
  Future<void> Function(BuildContext context, WidgetRef ref) action,
) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-06',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        readyWorkspaceContextProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () => action(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return money;
}

Future<void> _tapAndExpectSnack(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final snack = tester.widget<SnackBar>(find.byType(SnackBar));
  expect((snack.content as Text).data, startsWith(_said));
}

void main() {
  testWidgets('the EU sales list CSV answers instead of a dead tap', (
    tester,
  ) async {
    await _pump(
      tester,
      (context, ref) => saveRecapitulativeCsv(
        context,
        ref,
        start: DateTime(2026, 6),
        end: DateTime(2026, 7),
        currency: 'EUR',
      ),
    );
    await _tapAndExpectSnack(tester);
  });

  testWidgets('sharing a proforma answers instead of throwing', (tester) async {
    late FakeMoneyRepository money;
    money = await _pump(
      tester,
      (context, ref) => shareProforma(context, ref, money.invoices.single),
    );
    await _tapAndExpectSnack(tester);
  });

  testWidgets('the quick view of an invoice answers instead of throwing', (
    tester,
  ) async {
    late FakeMoneyRepository money;
    money = await _pump(
      tester,
      (context, ref) => quickViewInvoice(context, ref, money.invoices.single),
    );
    await _tapAndExpectSnack(tester);
  });

  testWidgets('the VAT report letter answers instead of throwing', (
    tester,
  ) async {
    await _pump(
      tester,
      (context, ref) => showVatReport(
        context,
        ref,
        start: DateTime(2026, 6),
        end: DateTime(2026, 7),
      ),
    );
    await _tapAndExpectSnack(tester);
  });

  testWidgets('the designer\'s live preview has no data, so it falls back to '
      'the sample', (tester) async {
    Map<String, Object?>? data = const {'sentinel': 1};
    var asked = false;
    await _pump(tester, (context, ref) async {
      await ref.read(invoicesProvider.future);
      if (!context.mounted) return;
      data = liveReportData(context, ref, 'workspace');
      asked = true;
    });
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('go')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(asked, isTrue);
    expect(data, isNull);
  });

  testWidgets('a guarded action that meets the refusal says so, with or '
      'without its own text', (tester) async {
    await _pump(
      tester,
      (context, ref) => runGuarded(
        context,
        domain: 'money',
        message: 'x failed',
        action: () async => throw const WorkspaceContextNotReady(),
      ),
    );
    await _tapAndExpectSnack(tester);
  });
}
