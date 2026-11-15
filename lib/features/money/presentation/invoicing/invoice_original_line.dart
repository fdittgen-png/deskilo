// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the invoice page's line for a stored original.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/invoice_original_providers.dart';

/// #3853 — who kept the invoice's original, when, and its SHA-256: the
/// fingerprint every download is checked against.
class InvoiceOriginalLine extends ConsumerWidget {
  const InvoiceOriginalLine({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kept = ref.watch(invoiceOriginalProvider(invoice.id)).value;
    if (kept == null) return const SizedBox.shrink();
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final who =
        [
          for (final m in members)
            if (m.userId == kept.storedBy) names[m.id] ?? '',
        ].firstOrNull ??
        '';
    final at = kept.storedAt;
    return Text(
      context.l10n.invoiceOriginalKept(
        at == null ? '' : appFormatOf(context).date(at),
        who,
        kept.pdfSha256,
      ),
      key: const ValueKey('invoice-page-original'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
