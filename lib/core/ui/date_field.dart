// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A date typed or picked (see lib/core/format/date_input.dart for the
// rules). What the field understood is written under it before anything
// is saved; a date it cannot read is refused in words under the field once
// the person leaves it, or as soon as the form asks for its problems.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../format/date_input.dart';
import '../i18n/format_controller.dart';
import '../l10n/context_l10n.dart';
import '../shortcuts/app_shortcuts.dart';
import '../shortcuts/shortcut_scope.dart';
import '../time/clock.dart';
import 'adaptive/task_surface.dart';
import 'form_kit.dart';

export '../format/date_input.dart' show DateInputProblem, DateRead;

/// The words for a refused date.
String dateInputProblemText(AppLocalizations l10n, DateInputProblem problem) {
  return switch (problem) {
    DateInputProblem.malformed => l10n.dateFieldMalformed,
    DateInputProblem.twoDigitYear => l10n.dateFieldTwoDigitYear,
    DateInputProblem.impossible => l10n.dateFieldImpossible,
    DateInputProblem.outOfRange => l10n.dateFieldOutOfRange,
  };
}

/// One date of a form: typed in the person's numeric date format (or as
/// eight digits in that order), or picked from the calendar button. Both
/// pass [readDateInput]; [onChanged] receives what the text reads as, so
/// the form can refuse a date it could not read instead of saving none.
class AppDateField extends StatefulWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.fieldKey,
    this.first,
    this.last,
    this.helper,
    this.error,
    this.showProblem = false,
    this.isRequired = false,
    this.pickerHelpText,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.help,
    this.locale,
  });

  final String label;

  /// The date the record holds; the text follows it when it changes from
  /// outside (a picked order, a reset).
  final DateTime? value;
  final ValueChanged<DateRead> onChanged;

  /// The key this field's problems are reported under in [FieldErrors].
  final String? fieldKey;

  /// The earliest and latest date the field accepts, typed or picked.
  final DateTime? first, last;
  final String? helper, error, pickerHelpText;

  /// Shows the problem of the current text even while the field has the
  /// focus: set by the form once a save was refused.
  final bool showProblem;

  /// Nothing typed is a problem too, said under the field.
  final bool isRequired;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled, autofocus;
  final Widget? help;

  /// The format locale; the person's (`appFormatOf`) when null.
  final String? locale;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  final _text = TextEditingController();
  FocusNode? _ownFocus;
  bool _left = false;
  bool _seeded = false;

  String get _locale => widget.locale ?? appFormatOf(context).locale;

  // The calendar's own span when the form names no bounds: a layout limit
  // of the picker, not a rule about which dates are allowed.
  DateTime get _first => widget.first ?? DateTime(1900);
  DateTime get _last => widget.last ?? DateTime(2200);

  FocusNode get _focus {
    final key = widget.fieldKey;
    final scoped = key == null
        ? null
        : FormErrorsScope.maybeOf(context)?.focusNodeFor?.call(key);
    return scoped ?? (_ownFocus ??= FocusNode());
  }

  DateRead _read() => readDateInput(
    _text.text,
    locale: _locale,
    first: widget.first,
    last: widget.last,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    if (widget.value case final value?) _write(value);
  }

  @override
  void didUpdateWidget(AppDateField old) {
    super.didUpdateWidget(old);
    final value = widget.value;
    if (value != old.value && value != _read().date) {
      value == null ? _text.clear() : _write(value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _write(DateTime date) =>
      _text.text = formatDateInput(date, locale: _locale);

  void _edited() {
    final key = widget.fieldKey;
    if (key != null) FormErrorsScope.maybeOf(context)?.onEdit(key);
    setState(() {});
    widget.onChanged(_read());
  }

  Future<void> _pick() async {
    final current = _read().date;
    DateTime now;
    try {
      now = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(clockProvider).now();
    } on StateError {
      now = _first;
    }
    final initial = current ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_first)
          ? _first
          : (initial.isAfter(_last) ? _last : initial),
      firstDate: _first,
      lastDate: _last,
      helpText: widget.pickerHelpText,
    );
    if (picked == null || !mounted) return;
    TaskSession.maybeOf(context)?.markChanged();
    _write(picked);
    _edited();
  }

  Future<void> _pickByKey() async {
    await _pick();
    if (mounted) _focus.requestFocus();
  }

  String? _problem(DateRead read) {
    final key = widget.fieldKey;
    final given =
        widget.error ??
        (key == null ? null : FormErrorsScope.maybeOf(context)?.errors[key]);
    if (given != null) return given;
    final missing = widget.isRequired && read.date == null;
    if (read.problem == null && !missing) return null;
    if (!widget.showProblem && (!_left || _focus.hasFocus)) return null;
    final problem = read.problem;
    return problem == null
        ? context.l10n.dateFieldRequired
        : dateInputProblemText(context.l10n, problem);
  }

  @override
  Widget build(BuildContext context) {
    final read = _read();
    final date = read.date;
    final material = MaterialLocalizations.of(context);
    final key = widget.key;
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (has) => setState(() => _left = _left || !has),
      // #3610 — Alt+Down (the registry's calendar key) opens the calendar
      // from the field, as desktop date fields do; the field keeps the
      // focus when it closes.
      onKeyEvent: (node, event) => widget.enabled
          ? runShortcuts(event, {
              AppShortcutId.openCalendar: () => unawaited(_pickByKey()),
            })
          : KeyEventResult.ignored,
      child: TextField(
        controller: _text,
        focusNode: _focus,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.datetime,
        textInputAction: widget.textInputAction,
        onChanged: (_) => _edited(),
        onSubmitted: widget.onSubmitted,
        inputFormatters: [_DateTidy()],
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: date == null
              ? widget.helper
              : context.l10n.dateFieldReadAs(
                  DateFormat.yMMMMEEEEd(_locale).format(date),
                ),
          helperMaxLines: 3,
          errorText: _problem(read),
          errorMaxLines: 3,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab moves from field to field; the calendar is for the
              // pointer, a keyboard types the date.
              ExcludeFocusTraversal(
                child: IconButton(
                  key: key is ValueKey<String>
                      ? ValueKey('${key.value}-pick')
                      : null,
                  tooltip: material.datePickerHelpText,
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: widget.enabled ? _pick : null,
                ),
              ),
              ?widget.help,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tidies what a keyboard or a paste brings and never removes a character:
/// a no-break or narrow space becomes a plain space.
class _DateTidy extends TextInputFormatter {
  static final _spaces = RegExp('[   ]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.replaceAll(_spaces, ' '));
}
