// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4516 -- the short step that lets a goods line be sold in a unit its item cannot yet convert to: "1 box = [n] pieces". The person says how
// many of the item's own unit one of the chosen unit holds; saving it makes an authored conversion of the item, and the line then takes the
// unit. Cancelling leaves the line as it was.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/conversion_factor.dart';

/// Asks how many [base] one [unit] holds; answers the fraction, or null when the person leaves.
Future<({int num, int den})?> askConversion(BuildContext context, {required String unit, required String base}) {
  return showDialog<({int num, int den})?>(
    context: context,
    builder: (context) => _ConversionDialog(unit: unit, base: base),
  );
}

class _ConversionDialog extends StatefulWidget {
  const _ConversionDialog({required this.unit, required this.base});

  final String unit;
  final String base;

  @override
  State<_ConversionDialog> createState() => _ConversionDialogState();
}

class _ConversionDialogState extends State<_ConversionDialog> {
  final _factor = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _factor.dispose();
    super.dispose();
  }

  void _save() {
    final read = parseConversionFactor(_factor.text);
    if (read == null) {
      setState(() => _error = context.l10n.standaloneInvoiceLineConversionInvalid);
      return;
    }
    Navigator.of(context).pop(read);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const ValueKey('goods-conversion-dialog'),
      title: Text(l.standaloneInvoiceLineConversionTitle(widget.unit, widget.base)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.standaloneInvoiceLineConversionHint(widget.unit, widget.base)),
          const FormGap(),
          Row(
            children: [
              Text(l.standaloneInvoiceLineConversionOne(widget.unit)),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  key: const ValueKey('goods-conversion-factor'),
                  controller: _factor,
                  label: l.standaloneInvoiceLineConversionFactor(widget.base),
                  error: _error,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('goods-conversion-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('goods-conversion-save'),
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
