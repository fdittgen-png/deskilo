// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C2 — the Overview's Needs attention section: my own unpaid
// documents, undecided requests and unread conversations, each read on its
// own and each record once. A source that cannot be read is said with its
// own Try again beside what the others answered; "nothing waits" is said
// only when every source answered in full. The legacy home's line of what
// I owe lives here too, so that one file of Me reads my documents.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/personal_kit/me_kit_metrics.dart';
import '../../../core/ui/private_value.dart';
import '../../directory/domain/inbox_composition.dart';
import '../../directory/domain/inbox_sources.dart';
import '../../directory/presentation/messenger/open_inbox_entry.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../money/presentation/my_finances_route.dart';
import '../../money/providers/finance_overview_provider.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_overview.dart';
import '../domain/personal_workspace_refs.dart';
import '../providers/me_providers.dart';
import 'kit/me_quiet_line.dart';
import 'kit/me_row.dart';
import 'kit/me_status_chip.dart';
import 'personal_overview_sections.dart';

/// How many items Needs attention lists before it says how many more wait:
/// a composition choice of this page, not a limit on what is read.
const int _attentionPreview = 5;

/// A note on what an answer covers.
class _CoverageNote extends StatelessWidget {
  const _CoverageNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: PersonalTheme.of(context).warning),
    ),
  );
}

/// What waits for me, or null while a source is not read yet: the first visit
/// decides "nothing here" from the same sources the section shows.
List<AttentionItem>? attentionItemsOf(
  WidgetRef ref,
  DateTime now,
  PersonalWorkspaceRefs? refs,
) {
  final documents = ref.watch(financeOverviewProvider);
  final inbox = ref.watch(messengerInboxProvider);
  final owed = documents.value
      ?.production(ref.watch(myDevelopmentWorkspaceIdsProvider))
      .outstanding;
  if (owed == null || inbox.value == null || refs == null) return null;
  return attentionItems(
    documents: [
      for (final d in owed)
        OwedDocument(
          id: d.id,
          workspaceId: d.workspaceId,
          workspaceName: d.workspaceName,
          number: d.number,
          remainingCents: d.remainingCents,
          currency: d.currency,
          dueOn: d.dueOn,
          overdue: d.overdueAt(now),
        ),
    ],
    refs: refs,
    inbox: inbox.value,
  );
}

/// My own unpaid documents, undecided requests and unread conversations,
/// each read on its own; each record once.
class NeedsAttentionSection extends ConsumerWidget {
  const NeedsAttentionSection({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final documents = ref.watch(financeOverviewProvider);
    final refs = ref.watch(personalWorkspaceRefsProvider);
    final inbox = ref.watch(messengerInboxProvider);
    final now = ref.watch(clockProvider).now();
    // Me is production: a development space's test documents never count.
    final owed = documents.value
        ?.production(ref.watch(myDevelopmentWorkspaceIdsProvider))
        .outstanding;
    // A refresh keeps what was read before; a failure says so beside it.
    final items = attentionItems(
      documents: owed == null
          ? null
          : [
              for (final d in owed)
                OwedDocument(
                  id: d.id,
                  workspaceId: d.workspaceId,
                  workspaceName: d.workspaceName,
                  number: d.number,
                  remainingCents: d.remainingCents,
                  currency: d.currency,
                  dueOn: d.dueOn,
                  overdue: d.overdueAt(now),
                ),
            ],
      refs: refsOfCurrentAccount(refs),
      inbox: inbox.value,
    );
    bool failed(AsyncValue<Object?> a) => a.hasError && !a.isLoading;
    final sources = [documents, refs, inbox];
    final reading = sources.any((a) => !a.hasValue && !failed(a));
    final settled = sources.every((a) => a.hasValue && !failed(a));
    final partialDocuments =
        documents.value?.unavailableSources.isNotEmpty ?? false;
    final read = inbox.value;
    // #2556 — a source that failed or cannot be reached is said beside the
    // others, never counted as nothing waiting.
    final partialInbox = (read?.unavailable.isNotEmpty ?? false) ||
        (read is ComposedInbox &&
            read.sources.any((s) =>
                s.state == InboxSlotState.failed ||
                s.state == InboxSlotState.unavailable));
    return OverviewSection(
      sectionKey: 'me-overview-attention',
      title: l10n.meOverviewAttentionTitle,
      expanded: expanded,
      children: [
        if (failed(documents))
          SourceUnavailable(
            key: const ValueKey('me-overview-documents-unavailable'),
            text: l10n.meOverviewAttentionDocumentsUnavailable,
            onRetry: () => ref.invalidate(financeOverviewProvider),
          )
        else if (partialDocuments)
          _CoverageNote(
            key: const ValueKey('me-overview-documents-partial'),
            text: l10n.meOverviewAttentionDocumentsPartial,
          ),
        if (failed(refs))
          SourceUnavailable(
            key: const ValueKey('me-overview-applications-unavailable'),
            text: l10n.meOverviewAttentionApplicationsUnavailable,
            onRetry: () => ref.invalidate(personalWorkspaceRefsProvider),
          ),
        if (failed(inbox))
          SourceUnavailable(
            key: const ValueKey('me-overview-messages-unavailable'),
            text: l10n.meOverviewAttentionMessagesUnavailable,
            onRetry: () => ref.invalidate(messengerInboxProvider),
          )
        else if (partialInbox)
          _CoverageNote(
            key: const ValueKey('me-overview-messages-partial'),
            text: l10n.meOverviewAttentionMessagesPartial,
          ),
        for (final item in items.take(_attentionPreview))
          _AttentionRow(item: item),
        if (items.length > _attentionPreview)
          Text(
            l10n.meOverviewAttentionMore(items.length - _attentionPreview),
            key: const ValueKey('me-overview-attention-more'),
          ),
        if (reading)
          const SectionLoading(key: ValueKey('me-overview-attention-loading'))
        else if (settled && items.isEmpty && !partialDocuments && !partialInbox)
          MeQuietLine(
            l10n.meOverviewAttentionNone,
            key: const ValueKey('me-overview-attention-none'),
          ),
      ],
    );
  }
}

/// One thing that waits: a row of Me whose whole text is the one button that
/// leads to it, named by what and where. The amount of a document is private:
/// masked until revealed, its own target beside the row's button.
class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = item.document;
    final (icon, title, detail, chip, onTap) = switch (item.kind) {
      AttentionKind.document => (
        Icons.receipt_long_outlined,
        l10n.meOverviewAttentionDocumentTitle(d!.number, d.workspaceName),
        d.dueOn == null
            ? null
            : l10n.meOverviewAttentionDue(
                ref.watch(appFormatProvider).date(d.dueOn!),
              ),
        MeStatusChip(
          kind: d.overdue ? MeChipKind.overdue : MeChipKind.toPay,
          label: d.overdue
              ? l10n.meOverviewAttentionOverdue
              : l10n.meOverviewAttentionToPay,
        ),
        () => context.push(myFinancesRoute(workspaceId: d.workspaceId)),
      ),
      AttentionKind.application => (
        Icons.hourglass_top_outlined,
        item.application!.label ?? l10n.meRefUnnamed,
        l10n.meOverviewAttentionApplication(
          item.application!.label ?? l10n.meRefUnnamed,
        ),
        null,
        () => context.push('/applications'),
      ),
      AttentionKind.conversation => (
        Icons.forum_outlined,
        item.conversation!.title.isNotEmpty
            ? item.conversation!.title
            : item.conversation!.workspaceName,
        l10n.meOverviewAttentionConversation(item.conversation!.unread),
        null,
        () => unawaited(openInboxEntry(context, ref, item.conversation!)),
      ),
    };
    final row = MeRow(
      key: ValueKey('me-overview-action-${item.key}'),
      leading: Icon(icon),
      title: title,
      subtitle: detail,
      semanticLabel: [title, ?detail].join('. '),
      trailing: chip,
      onTap: onTap,
    );
    return Padding(
      key: ValueKey('me-overview-${item.key}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: d == null
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [row, _Amount(item: item, document: d)],
            ),
    );
  }
}

/// A document's amount in its own currency, masked until revealed.
class _Amount extends ConsumerWidget {
  const _Amount({required this.item, required this.document});

  final AttentionItem item;
  final OwedDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = document;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: MeKitMetrics.tile + MeKitMetrics.gap,
      ),
      child: PrivateValue(
        revealKey: ValueKey('me-overview-amount-${item.key}'),
        maskedText: l10n.financesAmountMasked(d.currency),
        hiddenLabel: l10n.financesAmountHidden,
        showLabel: l10n.financesShowAmount,
        hideLabel: l10n.financesHideAmount,
        child: Text(
          ref.watch(appFormatProvider).money(d.remainingCents, currency: d.currency),
        ),
      ),
    );
  }
}

/// The legacy home's (shell off) line of what I owe, across every space,
/// and a way into Me › Finances; kept beside the Overview's Needs
/// attention so that one file reads my documents. Nothing at
/// all while there is nothing to pay (or the read fails): the home is not a
/// dashboard of empty states.
class FinanceGlance extends ConsumerWidget {
  const FinanceGlance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Me is production: a development space's test invoices never count.
    final data = ref
        .watch(financeOverviewProvider)
        .value
        ?.production(ref.watch(myDevelopmentWorkspaceIdsProvider));
    if (data == null || data.outstanding.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = ref.watch(clockProvider).now();
    final overdue = data.outstanding.where((i) => i.overdueAt(now)).length;
    final scheme = Theme.of(context).colorScheme;
    final tone = overdue > 0 ? scheme.error : scheme.primary;
    final strong = Theme.of(context).textTheme.titleSmall?.strong;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Material(
        key: const ValueKey('me-home-finance-glance'),
        color: tone.withValues(alpha: .10),
        borderRadius: AppRadius.xlAll,
        child: InkWell(
          key: const ValueKey('me-home-tab-finance-glance-owed'),
          borderRadius: AppRadius.xlAll,
          onTap: () => context.push(myFinancesRoute()),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // #2552: each amount is private, masked until
                      // revealed, as on the Overview and Finances.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.xs,
                        children: [
                          Text(l10n.meFinanceGlanceOwed, style: strong),
                          for (final e in data.owedByCurrency.entries)
                            PrivateValue(
                              revealKey: ValueKey(
                                'me-home-finance-glance-amount-${e.key}',
                              ),
                              maskedText: l10n.financesAmountMasked(e.key),
                              hiddenLabel: l10n.financesAmountHidden,
                              showLabel: l10n.financesShowAmount,
                              hideLabel: l10n.financesHideAmount,
                              child: Text(
                                appFormatOf(context).moneyIn(e.key).formatMinor(e.value),
                                style: strong,
                              ),
                            ),
                        ],
                      ),
                      if (overdue > 0)
                        Text(
                          l10n.financesOverdueCount(overdue),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
