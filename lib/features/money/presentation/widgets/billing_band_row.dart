// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/l10n/context_l10n.dart';

/// One editable band: the upper boundary plus its two prices. The lower
/// boundary is derived from the previous row, so the set always tiles
/// (0, 100] once every `toPct` is valid.
class BillingBandDraft {
  BillingBandDraft({
    required this.toPct,
    required this.feeCents,
    required this.overageCents,
  });

  int? toPct;
  int? feeCents;
  int? overageCents;
}

/// The row of one [BillingBandDraft]: "from X %", the boundary, the fee and
/// the overage fee — each with a persistent label and the workspace
/// currency beside the amounts (#3072).
class BillingBandRow extends StatelessWidget {
  const BillingBandRow({
    super.key,
    required this.index,
    required this.draft,
    required this.from,
    required this.isLast,
    required this.currencySymbol,
    required this.vatShare,
    required this.onEdited,
    required this.onRemove,
  });

  final int index;
  final BillingBandDraft draft;
  final int from;
  final bool isLast;
  final String currencySymbol;

  /// "incl. VAT x" for a gross amount, or null (#537).
  final String? Function(int? cents) vatShare;
  final VoidCallback onEdited;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(l10n.billingBandFrom(from))),
          Expanded(
            child: TextFormField(
              key: ValueKey('billing-band-to-$index'),
              enabled: !isLast,
              initialValue: '${draft.toPct ?? ''}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.billingBandTo),
              // The keyed rows keep their field edit state: initialValue is
              // only read on the element's first build.
              onChanged: (raw) {
                draft.toPct = int.tryParse(raw.trim());
                onEdited();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey('billing-band-fee-$index'),
              initialValue: centsToMajor(draft.feeCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.billingBandFee,
                suffixText: currencySymbol,
                helperText: vatShare(draft.feeCents),
              ),
              onChanged: (raw) {
                draft.feeCents = parseCentsInput(raw);
                onEdited();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey('billing-band-overage-$index'),
              initialValue: centsToMajor(draft.overageCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.billingBandOverage,
                suffixText: currencySymbol,
                helperText: vatShare(draft.overageCents),
              ),
              onChanged: (raw) {
                draft.overageCents = parseCentsInput(raw);
                onEdited();
              },
            ),
          ),
          if (isLast)
            // The last band always ends at 100% and cannot be removed; hide
            // the button instead of disabling it (#194) but keep the row
            // columns aligned with the IconButton's footprint.
            const SizedBox(width: 48)
          else
            IconButton(
              key: ValueKey('billing-remove-band-$index'),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: l10n.billingRemoveBand,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
