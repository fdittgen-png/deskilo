// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The rent a lease expects, month by month, and the bills that replaced it:
// the page reads as expected / partly / matched, a match leaves the variance
// visible, the commands send nothing for an empty or non-positive entry, and
// the sheet goes from the month to the bill and back (reversal).
import 'package:deskilo/core/demo/data/lease_commitment_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/application/commitment_commands.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/lease_commitments_sheet.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

CommitmentOccurrence _occurrence(
  String id,
  int month, {
  int matched = 0,
  List<CommitmentMatch> matches = const [],
}) => CommitmentOccurrence(
  id: id,
  dueOn: DateTime(2026, month),
  expectedCents: 100000,
  matchedCents: matched,
  matches: matches,
);

PurchaseDetail _bill() => const PurchaseDetail(
  summary: PurchaseSummary(
    id: 'b1',
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: 'Rent',
    reference: 'R-JAN',
    currency: 'EUR',
    grossCents: 105000,
  ),
  revision: 1,
  lines: [PurchaseLine(lineNo: 1, description: 'Rent', grossCents: 105000)],
  sources: [],
  supplierName: 'SCI Les Halles',
);

void main() {
  test('an occurrence reads as expected, partly matched or matched', () {
    expect(_occurrence('a', 1).state, CommitmentState.expected);
    expect(_occurrence('a', 1, matched: 60000).state, CommitmentState.partial);
    expect(_occurrence('a', 1, matched: 100000).state, CommitmentState.matched);
    expect(_occurrence('a', 1, matched: 60000).remainingCents, 40000);
    final page = CommitmentPage.fromJson({
      'occurrences': [
        {
          'id': 'o1',
          'due_on': '2026-01-01',
          'expected_cents': 100000,
          'matched_cents': 100000,
          'matches': [
            {
              'id': 'm1',
              'purchase_id': 'p1',
              'line_no': 1,
              'allocated_cents': 100000,
              'reference': 'R-JAN',
              'line_unallocated_cents': 5000,
            },
          ],
        },
      ],
      'next_before': '2026-01-01',
    });
    expect(page.occurrences.single.matches.single.lineUnallocatedCents, 5000);
    expect(page.nextBefore, DateTime(2026));
  });

  test('the commands send nothing for an empty entry or a reversal without a reason', () async {
    final repo = FakeLeaseCommitmentRepository({
      'L': [_occurrence('o1', 1)],
    });
    final commands = CommitmentCommands(repo);
    expect(
      await commands.match(
        'ws',
        const CommitmentMatchCommand(
          purchaseId: 'b1',
          revision: 1,
          allocations: [],
          requestId: 'r1',
        ),
      ),
      isFalse,
    );
    expect(
      await commands.match(
        'ws',
        const CommitmentMatchCommand(
          purchaseId: 'b1',
          revision: 1,
          allocations: [
            CommitmentAllocation(occurrenceId: 'o1', lineNo: 1, cents: 0),
          ],
          requestId: 'r2',
        ),
      ),
      isFalse,
    );
    expect(
      await commands.reverse('ws', matchId: 'm', reason: '  ', requestId: 'r3'),
      isFalse,
    );
    expect(
      (await repo.fetchCommitments('ws', 'L')).occurrences.single.matchedCents,
      0,
    );
  });

  testWidgets('the sheet matches a bill to a month and reverses it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final commitments = FakeLeaseCommitmentRepository({
      'L': [_occurrence('o1', 1)],
    });
    final purchases = FakePurchaseRepository()..add(_bill());
    Future<void> open({required bool canMatch}) async {
      await tester.pumpWidget(
        _app(
          LeaseCommitmentsView(
            workspaceId: 'ws',
            leaseId: 'L',
            currencyCode: 'EUR',
            canMatch: canMatch,
          ),
          [
            leaseCommitmentRepositoryProvider.overrideWithValue(commitments),
            purchaseRepositoryProvider.overrideWithValue(purchases),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    await open(canMatch: false);
    expect(find.byKey(const ValueKey('commitment-state-o1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('commitment-state-o1')))
          .data,
      endsWith('Expected'),
    );
    expect(find.byKey(const ValueKey('commitment-match-add-o1')), findsNothing);

    await open(canMatch: true);
    await tester.tap(find.byKey(const ValueKey('commitment-match-add-o1')));
    await tester.pumpAndSettle();
    // Nothing chosen yet: the save button is off, so nothing is sent.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('match-save')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('match-bill')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('R-JAN').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('match-amount')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '1000',
      reason: 'the month still expects 1 000.00: that is the default',
    );
    await tester.tap(find.byKey(const ValueKey('match-save')));
    await tester.pumpAndSettle();
    final matched = (await commitments.fetchCommitments(
      'ws',
      'L',
    )).occurrences.single;
    expect(matched.matchedCents, 100000);
    expect(matched.state, CommitmentState.matched);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('commitment-state-o1')))
          .data,
      endsWith('Matched'),
    );

    await tester.tap(
      find.byKey(ValueKey('commitment-reverse-${matched.matches.single.id}')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('match-reverse-reason')),
      'wrong month',
    );
    await tester.tap(find.byKey(const ValueKey('match-reverse-confirm')));
    await tester.pumpAndSettle();
    final back = (await commitments.fetchCommitments(
      'ws',
      'L',
    )).occurrences.single;
    expect(back.matchedCents, 0, reason: 'January expects its rent again');
    expect(back.state, CommitmentState.expected);
  });
}
