// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../application/set_member_customer_capacity.dart';
import '../domain/member.dart';
import '../providers/workspace_providers.dart';

/// #1916 — the name of a customer capacity wire ('' / null = not stated).
String customerCapacityName(AppLocalizations l10n, String? wire) =>
    switch (wire) {
      'business' => l10n.customerCapacityBusiness,
      'consumer' => l10n.customerCapacityConsumer,
      _ => l10n.customerCapacityNotStated,
    };

/// #1916 (migration 0349) — whether [member] acts as a business or a
/// consumer customer. Whoever may issue invoices; the server checks.
Future<void> pickMemberCustomerCapacity(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = context.l10n;
  var chosen = member.customerCapacity ?? '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(scrollable: true,
        title: Text(l10n.customerCapacityLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.customerCapacityExplainer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final wire in customerCapacityWires)
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
            key: const ValueKey('member-customer-capacity-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('customer-capacity-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  var changed = false;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'customer capacity update failed',
    errorText:
        l10n.customerCapacitySaveError,
    action: () async => changed = await ref
        .read(memberCustomerCapacitiesProvider)
        .set(member, chosen),
  )) {
    return;
  }
  if (changed) ref.invalidate(workspaceMembersProvider);
}
