// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/carnets.dart';
import '../../providers/credit_providers.dart';

/// #1279 — on a member's page: how many carnet half-days they can still
/// spend, and — for whoever issues invoices — selling them another.
class MemberCarnetTile extends ConsumerWidget {
  const MemberCarnetTile({
    super.key,
    required this.memberId,
    required this.canSell,
  });

  final String memberId;
  final bool canSell;

  Future<void> _sell(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final products = [
      for (final p in await ref.read(creditProductsProvider.future))
        if (p.active) p,
    ];
    if (!context.mounted) return;
    final productId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n?.carnetSell ?? 'Sell a carnet'),
        children: [
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n?.carnetsEmpty ?? 'No carnet yet.'),
            ),
          for (final p in products)
            SimpleDialogOption(
              key: ValueKey('sell-carnet-${p.id}'),
              onPressed: () => Navigator.of(ctx).pop(p.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(l10n?.carnetSummary(
                        p.halfDays, centsToMajor(p.priceCents)) ??
                    '${p.halfDays} half-days · ${centsToMajor(p.priceCents)}'),
              ),
            ),
        ],
      ),
    );
    if (productId == null || !context.mounted) return;
    if (await runGuarded(
      context,
      domain: 'money',
      message: 'carnet sale failed',
      action: () => sellCarnet(ref, memberId, productId),
    )) {
      if (context.mounted) {
        AppSnack.success(context,
            l10n?.carnetSold ?? 'Carnet sold — charged once on this month\'s bill.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balance = ref.watch(memberCreditBalanceProvider(memberId)).value;
    return ListTile(
      key: const ValueKey('member-carnets'),
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(l10n?.carnetsTitle ?? 'Carnets'),
      subtitle: balance == null
          ? null
          : Text(l10n?.carnetBalance(balance) ?? '$balance half-days left'),
      trailing: canSell ? const Icon(Icons.add_shopping_cart) : null,
      onTap: canSell ? () => _sell(context, ref) : null,
    );
  }
}
