// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the direct entries of a business without places: its customers, its
// quotes, its invoices, a new invoice for a customer, and Me. They are the same
// pages the menu opens, asked by the same rule (`businessEntriesFor`); the card
// only puts them where the business opens.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/business_entries.dart';

class BusinessEntriesCard extends StatelessWidget {
  const BusinessEntriesCard({super.key, required this.entries});

  final List<BusinessEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget entry(
      String key,
      IconData icon,
      String label,
      String route, {
      bool primary = false,
    }) {
      void open() => primary ? context.push(route) : context.go(route);
      return primary
          ? FilledButton.icon(
              key: ValueKey(key),
              onPressed: open,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              key: ValueKey(key),
              onPressed: open,
              icon: Icon(icon),
              label: Text(label),
            );
    }

    return Card(
      key: const ValueKey('business-entries'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.businessEntriesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in entries)
                  switch (e) {
                    BusinessEntry.newInvoice => entry(
                      'business-entry-new-invoice',
                      Icons.post_add_outlined,
                      l10n.businessEntryNewInvoice,
                      '/invoicing/standalone/new',
                      primary: true,
                    ),
                    BusinessEntry.quotes => entry(
                      'business-entry-quotes',
                      Icons.request_quote_outlined,
                      l10n.quotesTitle,
                      '/money/quotes',
                    ),
                    BusinessEntry.customers => entry(
                      'business-entry-customers',
                      Icons.groups_outlined,
                      l10n.invoicingViewCustomers,
                      '/money/customers',
                    ),
                    BusinessEntry.invoices => entry(
                      'business-entry-invoices',
                      Icons.receipt_long_outlined,
                      l10n.customerPageInvoices,
                      '/invoices',
                    ),
                  },
                entry(
                  'business-entry-me',
                  Icons.person_outline,
                  l10n.meTabMe,
                  '/me',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
