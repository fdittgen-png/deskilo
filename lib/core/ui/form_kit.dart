// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The form kit: what every form in DesKilo is built from (see the
// deskilo-forms skill and test/lint/form_patterns_test.dart).
//
// It only gathers what the forms already repeated by hand:
//
//   * [FormGap] / [FormSection] — the vertical rhythm, from the spacing
//     tokens, instead of `SizedBox(height: 12)` written in every sheet;
//   * [AppTextField] — a labelled field with its helper, its error under
//     the field (announced by the platform), its keyboard, its autofill
//     hints and an optional help dot, all from the theme;
//   * [FormControllers] — the text controllers of a form, created on
//     demand and disposed together, instead of N declarations and N
//     `dispose()` lines;
//   * [AppFormSheet] — a modal form sheet with a pinned footer, a saving
//     state and the reason the server or the rules refused, shown above
//     the buttons; the sheet closes only when the submit succeeds.
//
// Validation stays domain-first: the rules live in a pure function that
// returns, per field, the key of what is wrong ([FieldErrors]); the form
// maps a key to its localized words and passes them to the field.
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'inline_banner.dart';

/// Per-field problems, keyed by the field's own key: what a domain
/// validator returns and what each [AppTextField] shows under itself.
typedef FieldErrors = Map<String, String>;

/// The space between two fields of a form.
class FormGap extends StatelessWidget {
  /// Between two fields.
  const FormGap({super.key}) : height = AppSpacing.md;

  /// Between a field and the line that belongs to it (a hint, a toggle).
  const FormGap.small({super.key}) : height = AppSpacing.sm;

  /// Before a new group of fields or the actions.
  const FormGap.large({super.key}) : height = AppSpacing.lg;

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// A titled group of fields, separated from the previous group.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const FormGap.small(),
        ...children,
      ],
    ),
  );
}

/// One text field of a form, styled by the theme.
///
/// [error] is shown under the field and announced by the platform's
/// semantics; [help] (usually a `HelpDot`) sits at the end of the field.
/// E-mail, name, phone and address fields pass [autofillHints].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.error,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.help,
  });

  final TextEditingController controller;
  final String label;
  final String? helper, error, suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText, autofocus, enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? help;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    maxLines: obscureText ? 1 : maxLines,
    maxLength: maxLength,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      errorText: error,
      errorMaxLines: 3,
      suffixText: suffixText,
      suffixIcon: help,
    ),
  );
}

/// The text controllers of one form: asked for by name, created on first
/// use, disposed together.
///
/// ```dart
/// final fields = FormControllers({'name': profile.name});
/// AppTextField(controller: fields['name'], label: …);
/// fields.text('name'); // trimmed
/// fields.dispose();    // once, in the State's dispose
/// ```
class FormControllers {
  FormControllers([Map<String, String> initial = const {}]) {
    initial.forEach(
      (key, value) => _all[key] = TextEditingController(text: value),
    );
  }

  final Map<String, TextEditingController> _all = {};
  bool _disposed = false;

  /// The controller of [key], created empty the first time it is asked for.
  TextEditingController operator [](String key) {
    assert(!_disposed, 'FormControllers used after dispose');
    return _all.putIfAbsent(key, TextEditingController.new);
  }

  /// The trimmed text of [key].
  String text(String key) => this[key].text.trim();

  /// Every field's trimmed text, by key.
  Map<String, String> get values => {
    for (final e in _all.entries) e.key: e.value.text.trim(),
  };

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final c in _all.values) {
      c.dispose();
    }
    _all.clear();
  }
}

/// A modal form sheet: a title, the fields (scrolling when the keyboard
/// is up), and a footer that stays in view with the cancel and the
/// primary action.
///
/// [onSubmit] does the whole job — check, save — and returns null when
/// it is done (the sheet then closes with `true`), or the reason it could
/// not, which the sheet shows above the buttons and keeps the sheet open
/// so the person can correct it. The primary button shows progress while
/// [onSubmit] runs and cannot be pressed twice.
///
/// Open it with [showAppFormSheet].
class AppFormSheet extends StatefulWidget {
  const AppFormSheet({
    super.key,
    required this.title,
    required this.builder,
    required this.submitLabel,
    required this.onSubmit,
    this.submitKey,
    this.errorKey = const ValueKey('form-sheet-error'),
    this.onDispose,
  });

  final String title;

  /// The fields. [refresh] rebuilds the sheet after a choice changes what
  /// it shows (a toggle revealing more fields).
  final List<Widget> Function(BuildContext context, VoidCallback refresh)
  builder;
  final String submitLabel;
  final Future<String?> Function() onSubmit;
  final Key? submitKey;
  final Key errorKey;

  /// Called once when the sheet goes away: where its [FormControllers]
  /// are disposed.
  final VoidCallback? onDispose;

  @override
  State<AppFormSheet> createState() => _AppFormSheetState();
}

class _AppFormSheetState extends State<AppFormSheet> {
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _problem = null;
    });
    final problem = await widget.onSubmit();
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The keyboard when it is up, otherwise the system navigation bar.
    final bottom = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const FormGap(),
                  ...widget.builder(context, () => setState(() {})),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_problem != null) ...[
                  InlineBanner(
                    key: widget.errorKey,
                    icon: Icons.error_outline,
                    text: _problem!,
                  ),
                  const FormGap(),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('form-sheet-cancel'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      key: widget.submitKey,
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.submitLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens an [AppFormSheet]; true when it was submitted successfully.
Future<bool> showAppFormSheet(BuildContext context, AppFormSheet sheet) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => sheet,
    ) ??
    false;
