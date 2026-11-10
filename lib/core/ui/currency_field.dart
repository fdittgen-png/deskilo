// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- the currency field of a form: a lookup over the ISO 4217 codes the
// app supports (the same list the workspace currency dropdown offers), each
// option "CHF · CHF Fr." -- the code and the symbol in the reader's locale;
// the controller keeps the code.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';

import '../i18n/money_format.dart';
import 'master_data_field.dart';

/// Every supported currency: its code and the symbol the reader knows it by.
List<MasterDataOption> _currencyOptions(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context)?.toString();
  return [
    for (final code in Currencies.selectable)
      MasterDataOption(
        code: code,
        name: moneyFormat(code, locale: locale).currencySymbol,
      ),
  ];
}

class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    required this.controller,
    required this.label,
    this.fieldKey,
    this.textKey,
    this.focusNode,
    this.helper,
    this.error,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? fieldKey;
  final Key? textKey;
  final FocusNode? focusNode;
  final String? helper;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => MasterDataField(
    controller: controller,
    label: label,
    options: _currencyOptions(context),
    fieldKey: fieldKey,
    textKey: textKey,
    focusNode: focusNode,
    helper: helper,
    error: error,
    enabled: enabled,
    onChanged: onChanged,
  );
}
