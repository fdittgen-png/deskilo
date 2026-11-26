// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the engagements of the services ordered, on a screen of their
// own (`/money/engagements`): what was ordered, for whom, where it came from and
// where it stands. A list that could not be read says so: it is never shown as
// "none". The right to issue invoices opens the New engagement door.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/service_fulfilment.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/service_fulfilment_providers.dart';
import '../engagements/direct_engagement_sheet.dart';
import '../engagements/engagement_text.dart';
import '../quotes/quote_text.dart';
import 'money_view_data.dart';

class ServiceFulfilmentsScreen extends ConsumerWidget {
  const ServiceFulfilmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canIssue = MoneyViewData.purchasePermissionNames(ref).contains('issueInvoices');
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.engagementsTitle),
        actions: [
          if (canIssue && workspace != null)
            OutlinedButton.icon(
              key: const ValueKey('engagement-new'),
              onPressed: () => _new(context, ref, workspace.id),
              icon: const Icon(Icons.add),
              label: Text(l10n.engagementsNew),
            ),
          HelpDot(l10n.engagementsTitle, anchor: HelpAnchor.moneyEngagements),
        ],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
                child: _Body(workspaceId: workspace.id),
              ),
            ),
    );
  }

  Future<void> _new(BuildContext context, WidgetRef ref, String workspaceId) async {
    final customers = ref.read(billingCustomersProvider(workspaceId)).value ?? const []; // empty-ok: no customers means the sheet offers none to choose
    final made = await showDirectEngagementSheet(
      context,
      commands: ref.read(serviceFulfilmentCommandProvider),
      workspaceId: workspaceId,
      customers: customers,
    );
    if (made) ref.invalidate(serviceFulfilmentsProvider(workspaceId));
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = ref.watch(serviceFulfilmentsProvider(workspaceId));
    final names = quoteCustomerNames(
      ref.watch(billingCustomersProvider(workspaceId)).value ?? const [], // empty-ok: the names only label the rows
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.engagementsIntro, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: AsyncReadBody(
            value: all,
            isEmpty: (items) => items.isEmpty,
            refusal: (error) => error is FulfilmentRefusal
                ? engagementRefusalText(l10n, error)
                : null,
            retryKey: const ValueKey('engagements-retry'),
            onRetry: () => ref.invalidate(serviceFulfilmentsProvider(workspaceId)),
            data: (items) => items.isEmpty
                ? EmptyState(
                    key: const ValueKey('engagements-empty'),
                    icon: Icons.assignment_turned_in_outlined,
                    title: l10n.engagementsEmpty,
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _Row(item: items[i], customer: names[items[i].subjectId]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.customer});

  final ServiceFulfilment item;
  final String? customer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: ValueKey('engagement-row-${item.id}'),
      title: Text(engagementScopeLine(item.scope)),
      subtitle: Text([?customer, engagementSourceLine(l10n, item)].join(' · ')),
      trailing: Text(engagementStateLabel(l10n, item.state), key: ValueKey('engagement-state-${item.id}')),
      onTap: () => context.go(Routes.moneyEngagement(item.id)),
    );
  }
}
