// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4233 — after the owner accepts a declared payment, the Overview agrees with
// the books: the request is no longer "waiting on a decision in the space", the
// overdue receivables fall by what was paid, and both stay so after the owner
// leaves the Overview and comes back. The #4224 test compares the stores; this
// one reads the screen's own providers and text.
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_descriptor.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_guide_walk.dart' show settleFrames;
import '../../helpers/demo_practice_owner_walk.dart';

const _waiting = ValueKey('overview-attention-space');
const _overdueModule = 'sales.overdue_receivables';

void main() {
  testWidgets('the practice Overview follows an accepted declared payment: no '
      'request waiting, less overdue, now and after coming back', (
    tester,
  ) async {
    final (_, container, router) = await openDemoSpaceAsOwner(
      tester,
      space: 'practice',
      size: const Size(1440, 900),
    );
    final workspaceId = container.read(currentWorkspaceProvider).value!.id;
    final money = container.read(moneyRepositoryProvider) as FakeMoneyRepository;
    final events = container.read(eventRepositoryProvider) as FakeEventRepository;

    // A customer of the practice declares an open invoice paid.
    final invoice = money.invoices.firstWhere(
      (i) =>
          i.period != null &&
          !i.isVoided &&
          i.totalCents > 0 &&
          (money.invoiceMatchesStore[i.id]?.paidCents ?? 0) == 0 &&
          !money.claims.values.any((c) => c.contains(i.id)),
    );
    final id = await money.declareInvoicesPaid(
      workspaceId: workspaceId,
      memberId: invoice.memberId,
      claim: InvoiceClaim(
        period: invoice.period!,
        amountCents: invoice.totalCents,
        invoiceIds: [invoice.id],
      ),
    );
    final at = events.events.indexWhere((e) => e.id == id);
    events.events[at] = events.events[at].copyWith(
      actorMemberId: invoice.memberId,
    );

    Future<double> overdue() async {
      final result = await container.read(
        biModuleResultProvider(
          workspaceId,
          _overdueModule,
          const BiQueryContext(),
        ).future,
      );
      return (result.total.current.value(KpiAggregation.lastAtCutoff) ?? -1)
          .toDouble();
    }

    Future<void> openOverview() async {
      router.go('/workspace-overview');
      await settleFrames(tester);
    }

    String? waitingText() => find.byKey(_waiting).evaluate().isEmpty
        ? null
        : tester.widget<Text>(find.byKey(_waiting)).data;

    final words = AppLocalizationsEn();
    // The declaration is new to the Overview: it reads it as a fresh visit.
    container
      ..invalidate(overviewFigureProvider)
      ..invalidate(attentionProvider);
    await openOverview();
    final overdueBefore = await overdue();
    expect(
      overdueBefore,
      greaterThanOrEqualTo(invoice.totalCents),
      reason: 'the declared invoice is overdue now (the figure is in cents)',
    );
    expect(waitingText(), words.overviewPendingInSpace(1));

    final ref =
        tester.element(find.byType(WorkspaceOverviewScreen)) as WidgetRef;
    expect(await decideEvent(ref, id, accept: true), isNull);
    await settleFrames(tester);

    for (final stage in ['at once', 'after coming back']) {
      if (stage != 'at once') {
        router.go('/money');
        await settleFrames(tester);
        await openOverview();
      }
      expect(
        waitingText(),
        isNot(words.overviewPendingInSpace(1)),
        reason: 'the request left the waiting list ($stage)',
      );
      expect(
        await overdue(),
        overdueBefore - invoice.totalCents,
        reason: 'the overdue receivables fell by the invoice ($stage)',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
