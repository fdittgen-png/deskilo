// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';

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
/// the overage fee — each a form-kit field with a persistent label and the
/// workspace currency beside the amounts (#3072).
///
/// The fields read the draft once, when the row is built: the parent keys a
/// row by its draft object and replaces (never mutates) a draft it changes,
/// so a changed boundary is a new row with fresh fields.
class BillingBandRow extends StatefulWidget {
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
  State<BillingBandRow> createState() => _BillingBandRowState();
}

class _BillingBandRowState extends State<BillingBandRow> {
  late final _to =
      TextEditingController(text: '${widget.draft.toPct ?? ''}');
  late final _fee =
      TextEditingController(text: centsToMajor(widget.draft.feeCents ?? 0));
  late final _overage = TextEditingController(
    text: centsToMajor(widget.draft.overageCents ?? 0),
  );

  @override
  void dispose() {
    _to.dispose();
    _fee.dispose();
    _overage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = widget.draft;
    const amount = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(l10n.billingBandFrom(widget.from))),
          Expanded(
            child: AppTextField(
              key: ValueKey('billing-band-to-${widget.index}'),
              controller: _to,
              label: l10n.billingBandTo,
              enabled: !widget.isLast,
              keyboardType: TextInputType.number,
              onChanged: (raw) {
                draft.toPct = int.tryParse(raw.trim());
                widget.onEdited();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              key: ValueKey('billing-band-fee-${widget.index}'),
              controller: _fee,
              label: l10n.billingBandFee,
              suffixText: widget.currencySymbol,
              helper: widget.vatShare(draft.feeCents),
              keyboardType: amount,
              onChanged: (raw) {
                draft.feeCents = appFormatOf(context).parseMinor(raw);
                widget.onEdited();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              key: ValueKey('billing-band-overage-${widget.index}'),
              controller: _overage,
              label: l10n.billingBandOverage,
              suffixText: widget.currencySymbol,
              helper: widget.vatShare(draft.overageCents),
              keyboardType: amount,
              onChanged: (raw) {
                draft.overageCents = appFormatOf(context).parseMinor(raw);
                widget.onEdited();
              },
            ),
          ),
          if (widget.isLast)
            // The last band always ends at 100% and cannot be removed; hide
            // the button instead of disabling it (#194) but keep the row
            // columns aligned with the IconButton's footprint.
            const SizedBox(width: 48)
          else
            IconButton(
              key: ValueKey('billing-remove-band-${widget.index}'),
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: l10n.billingRemoveBand,
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
