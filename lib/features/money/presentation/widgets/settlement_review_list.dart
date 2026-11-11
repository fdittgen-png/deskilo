// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- the settlement reports kept for review: a settlement the provider
// changed after it was recorded, or a cost in another currency than its
// settlement. The recorder refused them and booked nothing of them; the
// members who may see the finances were told. A person marks one handled
// with a note; a handled one leaves the waiting list and stays readable.
// Nothing is accepted here: correcting recorded amounts is an accounting
// correction.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/kit_metrics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/settlement_fetch.dart';
import '../../providers/settlement_review_providers.dart';

class SettlementReviewList extends ConsumerWidget {
  const SettlementReviewList({super.key, required this.workspaceId});

  final String workspaceId;

  static String sentence(AppLocalizations l10n, SettlementReview r) =>
      switch (r.reason) {
        SettlementReviewReason.costsChanged =>
          l10n.payConfigSettlementCostsChanged(r.settlementId),
        SettlementReviewReason.amountChanged =>
          l10n.payConfigSettlementAmountChanged(r.settlementId),
        SettlementReviewReason.currencyMismatch =>
          l10n.payConfigSettlementCurrencyMismatch(r.settlementId),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final read = ref.watch(settlementReviewListProvider(workspaceId));
    final reviews = read.value;
    if (reviews == null) {
      if (!read.hasError) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.payConfigSettlementsReviewUnreadable,
                key: const ValueKey('settlement-reviews-unreadable'),
              ),
            ),
            TextButton(
              key: const ValueKey('settlement-reviews-retry'),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(KitMetrics.minTarget),
              ),
              onPressed: () =>
                  ref.invalidate(settlementReviewListProvider(workspaceId)),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    final waiting = [
      for (final r in reviews)
        if (!r.handled) r,
    ];
    final handled = [
      for (final r in reviews)
        if (r.handled) r,
    ];
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('settlement-reviews'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (waiting.isNotEmpty)
            Text(
              l10n.payConfigSettlementsReviewTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          for (final r in waiting)
            Row(
              key: ValueKey(
                'settlement-review-${r.settlementId}-${r.reason.wire}',
              ),
              children: [
                Expanded(child: Text(sentence(l10n, r))),
                TextButton(
                  key: ValueKey('settlement-review-handle-${r.id}'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(KitMetrics.minTarget),
                  ),
                  onPressed: () => _handle(context, ref, r),
                  child: Text(l10n.payConfigSettlementHandle),
                ),
              ],
            ),
          if (handled.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.payConfigSettlementHandledTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final r in handled)
              Text(
                l10n.payConfigSettlementHandledLine(
                  sentence(l10n, r),
                  r.handledNote,
                ),
                key: ValueKey('settlement-review-handled-${r.id}'),
              ),
          ],
        ],
      ),
    );
  }

  /// Asks for the note, then marks [review] handled and reads the list again.
  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    SettlementReview review,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _HandleDialog(review: review),
    );
    if (note == null || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'payments',
      message: 'settlement review hand-off failed',
      action: () => ref
          .read(settlementReviewCommandsProvider)
          .markHandled(review.id, note),
    );
    ref.invalidate(settlementReviewListProvider(workspaceId));
  }
}

class _HandleDialog extends StatefulWidget {
  const _HandleDialog({required this.review});

  final SettlementReview review;

  @override
  State<_HandleDialog> createState() => _HandleDialogState();
}

class _HandleDialogState extends State<_HandleDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = _note.text.trim();
    return AlertDialog(
      title: Text(l10n.payConfigSettlementHandle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SettlementReviewList.sentence(l10n, widget.review)),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const ValueKey('settlement-review-note'),
              controller: _note,
              label: l10n.payConfigSettlementHandleNote,
              maxLines: 3,
              maxLength: settlementReviewNoteMax,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('settlement-review-handle-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('settlement-review-handle-confirm'),
          onPressed: note.isEmpty
              ? null
              : () => Navigator.of(context).pop(note),
          child: Text(l10n.payConfigSettlementHandle),
        ),
      ],
    );
  }
}
