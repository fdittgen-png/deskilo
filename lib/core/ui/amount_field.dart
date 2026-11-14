// SPDX-License-Identifier: AGPL-3.0-or-later
//
// An amount of money in one named currency (see
// lib/core/format/amount_input.dart for what counts as an amount). The
// figures are right-aligned and tabular, the record's currency stands
// beside them, and what cannot be read as an amount of that currency is
// refused in words under the field once the person leaves it, or as soon
// as the form asks for its problems. Nothing typed is ever deleted.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../format/amount_input.dart';
import '../i18n/format_controller.dart';
import '../l10n/context_l10n.dart';
import 'form_kit.dart';

export '../format/amount_input.dart'
    show AmountInputProblem, AmountRead, amountInputText;

/// The words for a refused amount of [currency].
String amountInputProblemText(
  AppLocalizations l10n,
  AmountInputProblem problem, {
  required String currency,
}) {
  return switch (problem) {
    AmountInputProblem.notANumber => l10n.amountFieldNotANumber,
    AmountInputProblem.negative => l10n.amountFieldNegative,
    AmountInputProblem.tooManyDecimals => l10n.amountFieldTooManyDecimals(
      Currencies.minorDigits(currency),
      currency,
    ),
  };
}

/// One amount of a form, in [currency] — the record's own, never a
/// default. The form reads it with [readAmountInput] (or
/// `AppFormat.readAmount`) under the same currency and sign rule.
class AppAmountField extends StatefulWidget {
  const AppAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.currency,
    required this.allowNegative,
    this.fieldKey,
    this.helper,
    this.error,
    this.showProblem = false,
    this.isRequired = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.help,
    this.locale,
  });

  final TextEditingController controller;
  final String label;

  /// The ISO 4217 code of the record the amount belongs to.
  final String currency;

  /// Whether the amount may be below zero (a credit, a correction).
  final bool allowNegative;

  /// The key this field's problems are reported under in [FieldErrors].
  final String? fieldKey;
  final String? helper, error;

  /// Shows the problem of the current text even while the field has the
  /// focus: set by the form once a save was refused.
  final bool showProblem;

  /// Nothing typed is a problem too, said under the field.
  final bool isRequired;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled, autofocus;
  final Widget? help;

  /// The format locale; the person's (`appFormatOf`) when null.
  final String? locale;

  @override
  State<AppAmountField> createState() => _AppAmountFieldState();
}

class _AppAmountFieldState extends State<AppAmountField> {
  FocusNode? _ownFocus;
  bool _left = false;

  FocusNode get _focus {
    final key = widget.fieldKey;
    final scoped = key == null
        ? null
        : FormErrorsScope.maybeOf(context)?.focusNodeFor?.call(key);
    return scoped ?? (_ownFocus ??= FocusNode());
  }

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  String? _problem() {
    final key = widget.fieldKey;
    final given =
        widget.error ??
        (key == null ? null : FormErrorsScope.maybeOf(context)?.errors[key]);
    if (given != null) return given;
    if (!widget.showProblem && (!_left || _focus.hasFocus)) return null;
    final read = readAmountInput(
      widget.controller.text,
      locale: widget.locale ?? appFormatOf(context).locale,
      currency: widget.currency,
      allowNegative: widget.allowNegative,
    );
    final problem = read.problem;
    if (problem != null) {
      return amountInputProblemText(
        context.l10n,
        problem,
        currency: widget.currency,
      );
    }
    return widget.isRequired && read.minor == null
        ? context.l10n.amountFieldRequired
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final digits = Currencies.minorDigits(widget.currency);
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (has) => setState(() => _left = _left || !has),
      // #3946 — a figure is one line: Up and Down take the caret to its
      // start or end, as in any single-line field. Flutter's own vertical
      // caret run asserts in an empty field whose text is aligned to the
      // end, so the field answers these keys itself.
      child: Actions(
        actions: {
          ExtendSelectionVerticallyToAdjacentLineIntent:
              CallbackAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
                onInvoke: (intent) => _caretToEdge(forward: intent.forward),
              ),
          ExtendSelectionVerticallyToAdjacentPageIntent:
              CallbackAction<ExtendSelectionVerticallyToAdjacentPageIntent>(
                onInvoke: (intent) => _caretToEdge(forward: intent.forward),
              ),
        },
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textAlign: TextAlign.end,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          keyboardType: TextInputType.numberWithOptions(
            decimal: digits > 0,
            signed: widget.allowNegative,
          ),
          inputFormatters: const [_AmountTidy()],
          textInputAction: widget.textInputAction,
          onChanged: (value) {
            final key = widget.fieldKey;
            if (key != null) FormErrorsScope.maybeOf(context)?.onEdit(key);
            setState(() {});
            widget.onChanged?.call(value);
          },
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helper,
            helperMaxLines: 3,
            errorText: _problem(),
            errorMaxLines: 3,
            suffixText: widget.currency,
            suffixIcon: widget.help,
          ),
        ),
      ),
    );
  }

  Object? _caretToEdge({required bool forward}) {
    final c = widget.controller;
    c.selection = TextSelection.collapsed(offset: forward ? c.text.length : 0);
    return null;
  }
}

/// Tidies the grouping and sign characters a keyboard or a paste brings
/// and never removes one: a no-break, narrow or thin space becomes a plain
/// space, a typographic apostrophe a plain one, a minus sign a hyphen. A
/// letter, an exponent or a second separator stays, for the field to
/// refuse with its reason.
class _AmountTidy extends TextInputFormatter {
  const _AmountTidy();

  static final _spaces = RegExp('[   ]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(
    text: newValue.text
        .replaceAll(_spaces, ' ')
        .replaceAll('’', "'")
        .replaceAll('−', '-'),
  );
}
