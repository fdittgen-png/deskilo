// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #956 — one word on an invoice: whether its fingerprint still matches
// the document. 'unverifiable' is a row signed before the formula was
// stamped whose columns later migrations rewrote — not an alteration
// anyone made, and the chip says so rather than crying wolf.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/status_colors.dart';
import '../../providers/money_providers.dart';

class InvoiceIntegrityChip extends ConsumerWidget {
  const InvoiceIntegrityChip({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return FutureBuilder<String>(
      future: ref.read(moneyRepositoryProvider).verifyInvoiceSignature(invoiceId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();
        final (label, color) = switch (status) {
          'verified' => (l10n.invoiceIntegrityVerified, AppEnvironmentColors.productionOf(Theme.of(context).brightness)),
          'altered' => (l10n.invoiceIntegrityAltered, Theme.of(context).colorScheme.error),
          _ => (l10n.invoiceIntegrityUnverifiable, Theme.of(context).colorScheme.outline),
        };
        return Chip(
          key: ValueKey('invoice-integrity-$invoiceId'),
          avatar: Icon(status == 'altered' ? Icons.warning_amber_outlined : Icons.verified_outlined, size: 16, color: color),
          label: Text(label),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}
