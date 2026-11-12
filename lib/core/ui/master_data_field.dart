// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- a form field that names master data (a country, a currency) offers
// the valid values; nobody guesses a code. The master data is global, set by
// the platform owner, never by a workspace owner: the options come from the
// app's catalogues, the field only picks among them.
//
// The field keeps the CODE in [controller], so every form that read a text
// field keeps reading the code: a pick stores the code, a typed or pasted
// code (or a name) that names an option is stored as its code, anything else
// is stored as typed and is NOT valid -- the field shows its error and the
// form's own validation refuses it on submit. A value that arrives already
// stored and outside the catalogue is shown with its error, never cleared.
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../text/collation.dart';
import 'adaptive/task_surface.dart';
import 'form_kit.dart';

/// One valid value: its code and its name in the reader's language.
class MasterDataOption {
  const MasterDataOption({required this.code, required this.name});

  final String code;
  final String name;

  /// "France · FR".
  String get label => name == code ? code : '$name · $code';
}

/// The option [text] names: its code, its name or its label, ignoring case and
/// accents; null when it names none.
@visibleForTesting
MasterDataOption? optionNamed(Iterable<MasterDataOption> options, String text) {
  final t = foldForSearch(text.trim());
  if (t.isEmpty) return null;
  for (final o in options) {
    if (foldForSearch(o.code) == t ||
        foldForSearch(o.name) == t ||
        foldForSearch(o.label) == t) {
      return o;
    }
  }
  return null;
}

/// The options whose name or code contains [query] (all of them when empty).
@visibleForTesting
List<MasterDataOption> optionsMatching(
  Iterable<MasterDataOption> options,
  String query,
) {
  final q = foldForSearch(query.trim());
  return [
    for (final o in options)
      if (q.isEmpty ||
          foldForSearch(o.name).contains(q) ||
          foldForSearch(o.code).contains(q))
        o,
  ];
}

/// The text field with a searchable list of [options] under it.
class MasterDataField extends StatefulWidget {
  const MasterDataField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    this.fieldKey,
    this.textKey,
    this.focusNode,
    this.helper,
    this.error,
    this.enabled = true,
    this.onChanged,
  });

  /// The key of the text field inside (the one tests and the recorder drive).
  final Key? textKey;

  /// An outside focus node (a screen that moves focus to the field).
  final FocusNode? focusNode;

  /// Holds the code (or what was typed when it names no option).
  final TextEditingController controller;
  final String label;
  final List<MasterDataOption> options;
  final String? fieldKey;
  final String? helper;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<MasterDataField> createState() => _MasterDataFieldState();
}

class _MasterDataFieldState extends State<MasterDataField> {
  late final TextEditingController _text = TextEditingController(
    text: _shown(widget.controller.text),
  );
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  String _shown(String code) =>
      optionNamed(widget.options, code)?.label ?? code;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_codeChanged);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_codeChanged);
    _focus.removeListener(_focusChanged);
    _text.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  /// The form wrote a code (a lookup result, a reset): show its label.
  void _codeChanged() {
    final option = optionNamed(widget.options, widget.controller.text);
    final shown = option?.label ?? widget.controller.text;
    if (!_focus.hasFocus && _text.text != shown) {
      _text.text = shown;
      if (mounted) setState(() {});
    }
  }

  /// The person typed or pasted: the code when it names an option.
  void _typed(String text) {
    final option = optionNamed(widget.options, text);
    final code = option?.code ?? text.trim();
    if (widget.controller.text != code) widget.controller.text = code;
    widget.onChanged?.call(code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = widget.controller.text.trim();
    // While the person is still typing, a partial text that some option
    // contains is not yet an error; once the field is left, or when nothing
    // contains it, a value that names no option is.
    final unknown =
        code.isNotEmpty &&
        optionNamed(widget.options, code) == null &&
        (!_focus.hasFocus ||
            optionsMatching(widget.options, _text.text).isEmpty);
    return RawAutocomplete<MasterDataOption>(
      textEditingController: _text,
      focusNode: _focus,
      displayStringForOption: (o) => o.label,
      optionsBuilder: (value) => optionsMatching(widget.options, value.text),
      onSelected: (o) {
        TaskSession.maybeOf(context)?.markChanged();
        widget.controller.text = o.code;
        widget.onChanged?.call(o.code);
        setState(() {});
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) =>
          AppTextField(
            key: widget.textKey,
            controller: textController,
            focusNode: focusNode,
            label: widget.label,
            fieldKey: widget.fieldKey,
            helper: widget.helper ?? l10n.masterDataSearchHint,
            error: widget.error ?? (unknown ? l10n.masterDataUnknownCode : null),
            enabled: widget.enabled,
            onChanged: _typed,
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    key: ValueKey<String>('master-data-option-${o.code}'),
                    title: Text(o.label),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
