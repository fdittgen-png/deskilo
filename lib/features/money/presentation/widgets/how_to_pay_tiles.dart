// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The bank details a country without IBAN needs on the how-to-pay
/// card (#711): bank name, account number, the routing code under its
/// LOCAL name (sort code / routing number / transit · institution),
/// and a BIC for cross-border transfers. One tile per filled field.
class BankDetailTiles extends ConsumerWidget {
  const BankDetailTiles({super.key, required this.instructions});

  final PaymentInstructions instructions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(children: [
// #711 — local bank details for the countries that do not
// bank by IBAN. One tile per filled field; the routing code
// wears its local name.
if (instructions.bankName.trim().isNotEmpty)
  ListTile(
    key: const Key('howToPayBankName'),
    leading: const Icon(Icons.account_balance_outlined),
    title: Text(l10n.paymentBankNameLabel),
    subtitle: Text(instructions.bankName.trim()),
  ),
if (instructions.accountNumber.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayAccountNumber'),
    icon: Icons.numbers_outlined,
    title: l10n.paymentAccountNumberLabel,
    value: instructions.accountNumber.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
if (instructions.bankCode.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayBankCode'),
    icon: Icons.route_outlined,
    title: bankCodeLabelFor(
      CountryCatalog.byCode(
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '',
      ).scheme,
      sortCode: l10n.paymentSortCodeLabel,
      routingNumber:
          l10n.paymentRoutingNumberLabel,
      transitNumber:
          l10n.paymentTransitNumberLabel,
      bankCode: l10n.paymentBankCodeLabel,
    ),
    value: instructions.bankCode.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
if (instructions.bic.trim().isNotEmpty)
  CopyTile(
    key: const Key('howToPayBic'),
    icon: Icons.swap_horiz_outlined,
    title: l10n.paymentBicLabel,
    value: instructions.bic.trim(),
    copiedMessage: l10n.paymentCopied,
  ),
    ]);
  }
}

/// A how-to-pay row whose value copies to the clipboard on tap (#155
/// IBAN pattern, shared with the #192 Wero/Lydia/Wise rows).
class CopyTile extends StatelessWidget {
  const CopyTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String title;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('how-to-pay-tiles-copy'),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.copy_outlined, size: 18),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        AppSnack.success(context, copiedMessage);
      },
    );
  }
}
