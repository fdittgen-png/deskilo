// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A stock quantity is typed the same way on every sheet: the decimal
// keyboard, digits and the two decimal marks only, and read exactly in the
// reader's own format (`1,5` in French, `1.5` in English), never through a
// `double` and never rounded.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart'
    show ExactQuantity, ExactQuantityResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/ui/form_kit.dart';

/// The quantity typed in [text], in the format of [locale]: the value, or why
/// it is none.
ExactQuantityResult stockQuantityOf(String text, {required String locale}) =>
    exactQuantityFromInput(text, locale: locale);

/// The quantity typed in [text] in the format of [locale], or null when it is
/// none.
ExactQuantity? stockQuantityOrNull(String text, {required String locale}) =>
    stockQuantityOf(text, locale: locale).value;

/// A quantity field: [label], [error] under it, the decimal keyboard and only
/// digits and decimal marks.
class StockQuantityField extends StatelessWidget {
  const StockQuantityField({
    super.key,
    required this.controller,
    required this.label,
    this.fieldKey,
    this.error,
    this.helper,
    this.suffixText,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? fieldKey;
  final String? error;
  final String? helper;
  final String? suffixText;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: controller,
    label: label,
    fieldKey: fieldKey,
    error: error,
    helper: helper,
    suffixText: suffixText,
    autofocus: autofocus,
    enabled: enabled,
    onChanged: onChanged,
    focusNode: focusNode,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
  );
}
