// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4476 -- the till's two price keys: Price override asks a price and its reason, kept on the receipt; Discount asks a
// percentage off the item's price. Both read the number in the reader's own decimal mark and hand it on as an exact
// decimal with a point; whether this cashier may, and within which limit, is the server's to say.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/form_scroll.dart';
import '../../domain/counter_till.dart';

/// The price and reason for [line], or null when the cashier went back; [typed] is what the keypad held.
Future<({String price, String reason})?> showTillPriceDialog(BuildContext context, TillLine line, {String? typed}) =>
    showDialog<({String price, String reason})>(context: context, builder: (_) => _PriceDialog(line: line, typed: typed, discount: false));

/// The discount in percent for [line], or null when the cashier went back; [typed] is what the keypad held.
Future<String?> showTillDiscountDialog(BuildContext context, TillLine line, {String? typed}) async =>
    (await showDialog<({String price, String reason})>(context: context, builder: (_) => _PriceDialog(line: line, typed: typed, discount: true)))?.price;

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.line, required this.typed, required this.discount});

  final TillLine line;
  final String? typed;
  final bool discount;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final TextEditingController _amount = TextEditingController(text: widget.typed ?? '');
  late final TextEditingController _reason = TextEditingController(text: widget.line.priceReason ?? '');
  bool _unreadable = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _done() {
    final exact = decimalTextFromInput(_amount.text, locale: appFormatOf(context).locale, grouping: false);
    if (exact == null || exact.isEmpty) {
      setState(() => _unreadable = true);
      return;
    }
    Navigator.of(context).pop((price: exact, reason: _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.discount;
    return AlertDialog(
      title: Text(widget.line.name),
      content: FormScroll(
        children: [
          AppTextField(
            key: ValueKey(d ? 'till-discount-percent' : 'till-price-amount'),
            controller: _amount,
            label: d ? l10n.tillDiscountField : l10n.tillPriceField,
            error: _unreadable ? l10n.tillPriceUnreadable : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            autofocus: true,
          ),
          if (!d) ...[
            const FormGap(),
            AppTextField(
              key: const ValueKey('till-price-reason'),
              controller: _reason,
              label: l10n.tillPriceReason,
              helper: l10n.tillPriceReasonHint,
              maxLength: TillLine.priceReasonMaxLength,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(key: const ValueKey('till-price-cancel'), onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(key: const ValueKey('till-price-confirm'), onPressed: _done, child: Text(MaterialLocalizations.of(context).okButtonLabel)),
      ],
    );
  }
}
