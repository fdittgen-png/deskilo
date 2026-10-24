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
import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../directory/domain/inbox_composition.dart';
import '../../directory/domain/inbox_sources.dart';
import '../../directory/presentation/messenger/open_inbox_entry.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../money/presentation/my_finances_route.dart';
import '../../money/providers/finance_overview_provider.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_overview.dart';
import '../providers/me_providers.dart';
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
          Text(
            l10n.meOverviewAttentionNone,
            key: const ValueKey('me-overview-attention-none'),
          ),
      ],
    );
  }
}

/// One thing that waits: what it is, and the one action that leads to it.
/// The row is not a button; its action is.
class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    final (icon, title, detail, action, onAction) = _describe(
      context,
      ref,
      l10n,
    );
    return Padding(
      key: ValueKey('me-overview-${item.key}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: item.overdue ? tokens.danger : tokens.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.strong,
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
                if (item.overdue)
                  Text(
                    l10n.meOverviewAttentionOverdue,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.danger,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: ValueKey('me-overview-action-${item.key}'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, PersonalShellMetrics.minTarget),
            ),
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }

  (IconData, String, String, String, VoidCallback) _describe(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    switch (item.kind) {
      case AttentionKind.document:
        final d = item.document!;
        final format = ref.watch(appFormatProvider);
        return (
          Icons.receipt_long_outlined,
          d.workspaceName,
          l10n.meOverviewAttentionDocument(
            format.money(d.remainingCents, currency: d.currency),
            d.number,
          ),
          l10n.meOverviewAttentionViewDocument,
          () => context.push(myFinancesRoute(workspaceId: d.workspaceId)),
        );
      case AttentionKind.application:
        final name = item.application!.label ?? l10n.meRefUnnamed;
        return (
          Icons.hourglass_top_outlined,
          name,
          l10n.meOverviewAttentionApplication(name),
          l10n.mySpacesRequestStatus,
          () => context.push('/applications'),
        );
      case AttentionKind.conversation:
        final c = item.conversation!;
        return (
          Icons.forum_outlined,
          c.title.isNotEmpty ? c.title : c.workspaceName,
          l10n.meOverviewAttentionConversation(c.unread),
          l10n.meOverviewAttentionOpenConversation,
          () => unawaited(openInboxEntry(context, ref, c)),
        );
    }
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
    final amount = [
      for (final e in data.owedByCurrency.entries)
        moneyFormat(e.key).formatMinor(e.value),
    ].join(' · ');
    final tone = overdue > 0 ? scheme.error : scheme.primary;
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
                      Text(
                        l10n.meFinanceGlanceOwed(amount),
                        style: Theme.of(context).textTheme.titleSmall?.strong,
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
