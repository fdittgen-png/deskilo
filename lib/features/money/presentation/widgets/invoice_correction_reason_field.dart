// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/jurisdiction/installed_invoice_mentions.dart';
import '../../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../l10n/app_localizations.dart';

/// #2440 — RD 1619/2012 art. 15: the reason (R1-R5) a Spanish seller gives
/// for a correcting invoice. The issue form shows it only when the server's
/// readiness answer names `correction_reason`, so no country is guessed.
class InvoiceCorrectionReasonField extends StatelessWidget {
  const InvoiceCorrectionReasonField({
    super.key,
    required this.country,
    required this.value,
    required this.onChanged,
  });

  /// The workspace's country: the codes are its law's own.
  final String country;

  /// The chosen code; '' = none yet.
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The codes are the country's own, asked of its mentions add-on: no
    // country is named here.
    final codes = switch (resolveInvoiceMentions(
      LegalContext(countryCode: country),
      installedInvoiceMentions,
    )) {
      ResolvedMentions(:final contribution) =>
        contribution.correctionReasonCodes,
      _ => const <String>[],
    };
    if (codes.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      key: const ValueKey('invoice-correction-reason'),
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      items: [
        for (final code in codes)
          DropdownMenuItem(
            value: code,
            child: Text(_label(l10n, code), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: l10n.invoiceCorrectionReason),
    );
  }
}

String _label(AppLocalizations l10n, String code) => switch (code) {
      'R1' => l10n.invoiceCorrectionReasonR1,
      'R2' => l10n.invoiceCorrectionReasonR2,
      'R3' => l10n.invoiceCorrectionReasonR3,
      'R4' => l10n.invoiceCorrectionReasonR4,
      'R5' => l10n.invoiceCorrectionReasonR5,
      _ => code,
    };
