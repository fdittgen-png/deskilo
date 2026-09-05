// SPDX-License-Identifier: 0BSD
//
// #880 — the owner's texts, per language: a key, a value, and nothing
// about WHERE it prints — that is the design's business
// (`{{ text.<key> }}`). Editing a language overlay shows the default
// language's value as the hint an empty field falls back to.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class ReportTextsPanel extends StatefulWidget {
  const ReportTextsPanel({
    super.key,
    required this.language,
    required this.texts,
    required this.inherited,
    required this.onChanged,
  });

  /// '' for the default language.
  final String language;

  /// This language's own values.
  final Map<String, String> texts;

  /// The default language's values (empty when editing it).
  final Map<String, String> inherited;
  final ValueChanged<Map<String, String>> onChanged;

  static final RegExp keyPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  State<ReportTextsPanel> createState() => _ReportTextsPanelState();
}

class _ReportTextsPanelState extends State<ReportTextsPanel> {
  final Map<String, TextEditingController> _controllers = {};

  /// The add-dialog's controller: kept until the panel goes, because
  /// the dialog's route is still animating out when the future returns.
  TextEditingController? _keyController;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _keyController?.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: widget.texts[key] ?? ''),
  );

  List<String> get _keys =>
      {...widget.inherited.keys, ...widget.texts.keys}.toList()..sort();

  void _set(String key, String value) =>
      widget.onChanged({...widget.texts, key: value});

  // The field's controller stays until the panel is disposed: the row
  // is still on screen for the frame that removes it.
  void _remove(String key) => widget.onChanged({...widget.texts}..remove(key));

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    _keyController?.dispose();
    final controller = _keyController = TextEditingController();
    String? error;
    final key = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n?.reportTextsAdd ?? 'Add a text'),
          content: TextField(
            key: const ValueKey('report-texts-key-field'),
            controller: controller,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n?.reportTextsKey ?? 'Key',
              helperText:
                  l10n?.reportTextsKeyHint ??
                  'Letters, digits and underscores, e.g. greeting',
              prefixText: 'text.',
              errorText: error,
            ),
            onSubmitted: (_) => _submit(
              dialogContext,
              controller.text,
              l10n,
              (e) => setDialogState(() => error = e),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n?.commonCancel ?? 'Cancel'),
            ),
            FilledButton(
              key: const ValueKey('report-texts-key-confirm'),
              onPressed: () => _submit(
                dialogContext,
                controller.text,
                l10n,
                (e) => setDialogState(() => error = e),
              ),
              child: Text(l10n?.reportTextsAdd ?? 'Add a text'),
            ),
          ],
        ),
      ),
    );
    if (key == null) return;
    _set(key, '');
  }

  void _submit(
    BuildContext dialogContext,
    String raw,
    AppLocalizations? l10n,
    void Function(String?) setError,
  ) {
    final key = raw.trim().toLowerCase();
    if (!ReportTextsPanel.keyPattern.hasMatch(key)) {
      setError(
        l10n?.reportTextsKeyInvalid ??
            'Use letters, digits and underscores only, starting with a letter.',
      );
      return;
    }
    if (_keys.contains(key)) {
      setError(l10n?.reportTextsKeyExists ?? 'This key already exists.');
      return;
    }
    Navigator.of(dialogContext).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = '${_keys.length}';
    // Collapsed by default: the designer column stays as tall as it was
    // (a taller column scrolls its own toolbar out of reach).
    return Card(
      key: const ValueKey('report-texts-panel'),
      child: ExpansionTile(
        key: const ValueKey('report-texts-expand'),
        leading: const Icon(Icons.notes_outlined),
        title: Text(
          l10n?.reportTextsTitle ?? 'Texts',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(count, style: theme.textTheme.bodySmall),
        childrenPadding: AppSpacing.lgAll,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('report-texts-add'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l10n?.reportTextsAdd ?? 'Add a text'),
            ),
          ),
          Text(
            l10n?.reportTextsHint ??
                'Your own wording, placed in any band or layout as '
                    '{{ text.key }}. Each language may carry its own '
                    'value; an empty one falls back to the default '
                    'language.',
            style: theme.textTheme.bodySmall,
          ),
          for (final key in _keys) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('report-text-$key'),
                    controller: _controllerFor(key),
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'text.$key',
                      border: const OutlineInputBorder(),
                      hintText: widget.language.isEmpty
                          ? null
                          : widget.inherited[key],
                      helperText:
                          widget.language.isEmpty ||
                              (widget.inherited[key] ?? '').isEmpty
                          ? null
                          : l10n?.reportTextsInherited ?? 'Default language',
                    ),
                    onChanged: (v) => _set(key, v),
                  ),
                ),
                IconButton(
                  key: ValueKey('report-text-remove-$key'),
                  tooltip: l10n?.reportTextsRemove ?? 'Remove text',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(key),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
