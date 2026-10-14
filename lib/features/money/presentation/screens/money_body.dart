// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_frame.dart';
import '../../../../core/ui/loading_view.dart';
import '../widgets/invoice_overview.dart';
import '../widgets/money_attention_body.dart';
import '../widgets/money_faces_view.dart';
import 'money_action_set.dart';
import 'money_face_content.dart';
import 'money_period_header.dart';
import 'money_screen_ops.dart';
import 'money_view_data.dart';

/// The Money tab's content: the faces when the owner turned them on (#720),
/// else the classic bill column — split in a side panel in phone landscape
/// (#486). The screen's State keeps only the browsed month; everything this
/// widget reads it watches itself (#2494).
class MoneyBody extends ConsumerWidget {
  const MoneyBody({super.key, required this.ops});

  final MoneyScreenOps ops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = MoneyViewData.watch(ref, ops.period);
    final actions = MoneyActionSet.build(
      context,
      ref,
      ops: ops,
      data: data,
    );
    final content = MoneyFaceContent(
      context,
      ref,
      ops: ops,
      data: data,
      actions: actions,
    );
    final periodHeader = MoneyPeriodHeader(
      ops: ops,
      showExport: data.pdfExportOn,
      statement: data.statement,
    );
    final occurrenceCards = content.occurrenceCards();
    final exposure =
        watchExposure(ref, data.member?.id ?? '', data.currencyCode);
    // #486 — the landscape side panel leads with the month's BOTTOM LINE so
    // the split reads: my balance and what I can do, left; the detail,
    // right.
    final balanceCard = MoneyBalanceCard(
      balanceCents: data.statement?.balanceCents,
      currency: data.currency,
    );
    final classic = _ClassicColumn(
      periodHeader: periodHeader,
      balanceCard: balanceCard,
      actionChildren: content.actionChildren(occurrenceCards),
      billChildren: content.billChildren(),
    );
    return MoneyAttentionBody(
      enabled: data.eventsTabOn,
      child: switch (data.statementAsync) {
        AsyncData() when data.financeFacesOn =>
          MoneyFacesView(
            periodHeader: periodHeader,
            cards: content.cards(occurrenceCards, exposure),
            actions: content.faceActions(),
          ),
        AsyncData() => classic,
        AsyncError() => Center(
            child: Text(
              l10n.workspaceGenericError,
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

/// The classic layout: one scrolling column, or in phone landscape (#282
/// idiom, field request) the period header and the money actions in a side
/// panel so the bill fills the rest of the screen — the same layout family
/// as Plan/Reserve/Calendar.
class _ClassicColumn extends StatelessWidget {
  const _ClassicColumn({
    required this.periodHeader,
    required this.balanceCard,
    required this.actionChildren,
    required this.billChildren,
  });

  final Widget periodHeader;
  final Widget balanceCard;
  final List<Widget> actionChildren;
  final List<Widget> billChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (phoneLandscape(constraints)) {
          return Row(
            children: [
              SizedBox(
                // #486 — 32% (280–400dp): the bill is the content.
                width: (constraints.maxWidth * 0.32).clamp(280.0, 400.0),
                child: SingleChildScrollView(
                  padding: AppSpacing.mdAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // #606 — gated inside the widget.
                      const HelpHint(HelpHintId.money),
                      periodHeader,
                      balanceCard,
                      ...actionChildren,
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView(
                  padding: AppSpacing.mdAll,
                  children: billChildren,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: AppSpacing.mdAll,
          children: [
            // #606 — contextual how-to; gated inside the widget.
            const HelpHint(HelpHintId.money),
            periodHeader,
            ...billChildren,
            ...actionChildren,
          ],
        );
      },
    );
  }
}
