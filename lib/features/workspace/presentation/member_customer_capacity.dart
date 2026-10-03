// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/member.dart';
import '../providers/workspace_providers.dart';

/// #1916 — the name of a customer capacity wire ('' / null = not stated).
String customerCapacityName(AppLocalizations? l10n, String? wire) =>
    switch (wire) {
      'business' => l10n?.customerCapacityBusiness ?? 'Business',
      'consumer' => l10n?.customerCapacityConsumer ?? 'Consumer',
      _ => l10n?.customerCapacityNotStated ?? 'Not stated',
    };

/// #1916 (migration 0347) — whether [member] acts as a business or a
/// consumer customer. Whoever may issue invoices; the server checks.
Future<void> pickMemberCustomerCapacity(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  var chosen = member.customerCapacity ?? '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n?.customerCapacityLabel ?? 'Customer capacity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.customerCapacityExplainer ??
                  'Whether this customer acts for a trade or business or '
                      'as a private consumer. It decides which payment '
                      'clauses an invoice prints.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final wire in const ['', 'business', 'consumer'])
                  ChoiceChip(
                    key: Key(
                      'customer-capacity-${wire.isEmpty ? 'none' : wire}',
                    ),
                    label: Text(customerCapacityName(l10n, wire)),
                    selected: chosen == wire,
                    onSelected: (_) => setState(() => chosen = wire),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const Key('customer-capacity-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  if (chosen == (member.customerCapacity ?? '')) return;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'customer capacity update failed',
    errorText:
        l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberCustomerCapacity(member.id, chosen.isEmpty ? null : chosen),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}
