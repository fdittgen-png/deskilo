// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the billing customers on a screen of their own (`/money/customers`):
// the people and businesses the business invoices, with or without an account.
// The list is read under the rights that already read the customers' money; the
// add and edit doors need `manageBillingCustomers`. A list that could not be read
// says so: it is never shown as "no customers".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/collation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/billing_customer.dart';
import '../../providers/billing_customer_providers.dart';
import '../widgets/billing_access_dialog.dart';
import '../widgets/billing_customer_sheet.dart';
import 'money_view_data.dart';

class BillingCustomersScreen extends ConsumerStatefulWidget {
  const BillingCustomersScreen({super.key});

  @override
  ConsumerState<BillingCustomersScreen> createState() =>
      _BillingCustomersScreenState();
}

class _BillingCustomersScreenState
    extends ConsumerState<BillingCustomersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(BillingParty p, String query) {
    if (query.isEmpty) return true;
    final d = p.draft;
    return [p.displayName, d.city, d.email, d.vatId, d.countryCode].any(
      (field) => foldForSearch(field).contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final held = MoneyViewData.purchasePermissionNames(ref);
    final canManage = held.contains('manageBillingCustomers');
    final canSetCapacity = held.contains('issueInvoices');
    Future<void> open(BillingParty? existing) async {
      final id = workspace?.id;
      if (id == null) return;
      final saved = await showBillingCustomerSheet(
        context,
        commands: ref.read(billingCustomerCommandProvider),
        workspaceId: id,
        existing: existing,
        canSetCapacity: canSetCapacity,
      );
      if (saved) ref.invalidate(billingCustomersProvider(id));
    }

    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.billingCustomersTitle),
        actions: [
          if (canManage && workspace != null)
            OutlinedButton.icon(
              key: const ValueKey('billing-customer-add'),
              onPressed: () => open(null),
              icon: const Icon(Icons.add),
              label: Text(l10n.billingCustomersAdd),
            ),
          HelpDot(
            l10n.billingCustomersTitle,
            anchor: HelpAnchor.moneyBillingCustomers,
          ),
        ],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _body(context, workspace.id, canManage, open),
              ),
            ),
    );
  }

  Widget _body(
    BuildContext context,
    String workspaceId,
    bool canManage,
    Future<void> Function(BillingParty?) open,
  ) {
    final l10n = context.l10n;
    final customers = ref.watch(billingCustomersProvider(workspaceId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.billingCustomersNoAccount,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('billing-customers-search'),
                controller: _search,
                label: l10n.billingCustomersSearch,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: customers.when(
            loading: () => const LoadingView(),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ReadFailureBanner(
                error: error,
                refusal: error is BillingCustomerRefusal
                    ? l10n.billingCustomerNotAllowed
                    : null,
                retryKey: const ValueKey('billing-customers-retry'),
                onRetry: () =>
                    ref.invalidate(billingCustomersProvider(workspaceId)),
              ),
            ),
            data: (all) {
              final query = foldForSearch(_search.text.trim());
              final shown = [
                for (final p in all)
                  if (_matches(p, query)) p,
              ];
              if (all.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      l10n.billingCustomersEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = shown[i];
                  final d = p.draft;
                  final place = [
                    d.street,
                    '${d.postalCode} ${d.city}'.trim(),
                    d.countryCode,
                  ].where((s) => s.isNotEmpty).join(', ');
                  return ListTile(
                    key: ValueKey('billing-customer-row-${p.subjectId}'),
                    title: Text(p.displayName),
                    subtitle: place.isEmpty ? null : Text(place),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        switch (p.capacity) {
                          'business' => Text(l10n.billingCustomerBusiness),
                          'consumer' => Text(l10n.billingCustomerConsumer),
                          _ => const SizedBox.shrink(),
                        },
                        // #4164 B2 — the customer's own account access.
                        if (canManage)
                          IconButton(
                            key: ValueKey('billing-customer-access-${p.subjectId}'),
                            tooltip: l10n.billingAccessAction,
                            icon: const Icon(Icons.key_outlined),
                            onPressed: () => showBillingAccessDialog(
                              context,
                              commands: ref.read(billingAccessCommandProvider),
                              workspaceId: workspaceId,
                              customer: p,
                              now: ref.read(clockProvider).now,
                            ),
                          ),
                      ],
                    ),
                    onTap: canManage ? () => open(p) : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
