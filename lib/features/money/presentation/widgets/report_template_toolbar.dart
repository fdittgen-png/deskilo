// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's controls (#472, #474, #496, #864), moved out of
// invoice_template_sheet.dart: what is edited (language, document), the
// markup bands, and what can be done with them. They hold no state —
// the editor passes what is selected and is called back.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/report_template_assembly.dart';
import '../report_defaults.dart';
import '../report_design_actions.dart';

/// One template per LANGUAGE (#496): the default, plus an overlay per
/// language; a dot marks a language with its own bands (#822).
class ReportTemplateLanguageChips extends StatelessWidget {
  const ReportTemplateLanguageChips({
    super.key,
    required this.selected,
    required this.overridden,
    required this.canClear,
    required this.onSelect,
    required this.onClear,
  });

  /// '' for the default template.
  final String selected;
  final bool Function(String lang) overridden;

  /// Whether the selected overlay has bands to clear.
  final bool canClear;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EdgeFadeScroll(
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: const ValueKey('invoice-template-lang-default'),
              label: Text(
                l10n?.reportTemplateLangDefault ?? 'Default (all languages)',
              ),
              selected: selected.isEmpty,
              onSelected: (_) => onSelect(''),
            ),
          ),
          for (final lang in reportTemplateLanguages)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('invoice-template-lang-$lang'),
                // #1191 — the chip's own tick would land on the dot.
                showCheckmark: false,
                avatar: overridden(lang)
                    ? Icon(
                        Icons.circle,
                        key: ValueKey('invoice-template-lang-own-$lang'),
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                tooltip: overridden(lang)
                    ? (l10n?.reportTemplateLangOverridden ?? 'Own template')
                    : (l10n?.reportTemplateLangInherits ??
                          'Inherits the default'),
                label: Text(lang.toUpperCase()),
                selected: selected == lang,
                onSelected: (_) => onSelect(lang),
              ),
            ),
          if (selected.isNotEmpty && canClear)
            TextButton.icon(
              key: const ValueKey('invoice-template-clear-overlay'),
              icon: const Icon(Icons.layers_clear_outlined, size: 18),
              label: Text(
                l10n?.reportTemplateClearOverlay ??
                    'Use the default for this language',
              ),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

/// One report per DOCUMENT (#472): [docs] comes from the report-kind
/// registry, as `(id, label)`.
class ReportTemplateDocChips extends StatelessWidget {
  const ReportTemplateDocChips({
    super.key,
    required this.docs,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, String)> docs;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => EdgeFadeScroll(
    key: const ValueKey('invoice-template-docs'),
    child: Row(
      children: [
        for (final (doc, label) in docs)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('invoice-template-doc-$doc'),
              label: Text(label),
              selected: selected == doc,
              onSelected: (_) => onSelect(doc),
            ),
          ),
      ],
    ),
  );
}

/// The three bands as raw markup (#470); [onFocus] tells the editor
/// which band the markup guide inserts into (#966).
class ReportMarkupBands extends StatelessWidget {
  const ReportMarkupBands({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
    required this.onFocus,
  });

  final TextEditingController header, body, footer;
  final ValueChanged<TextEditingController> onFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget band(
      TextEditingController controller,
      String label, {
      required String key,
      int minLines = 3,
    }) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        onTap: () => onFocus(controller),
        minLines: minLines,
        maxLines: 14,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        band(
          header,
          l10n?.invoiceTemplateHeaderLabel ?? 'Header band',
          key: 'invoice-template-header',
        ),
        band(
          body,
          l10n?.invoiceTemplateBodyLabel ?? 'Body band (the invoice lines)',
          key: 'invoice-template-body',
          minLines: 5,
        ),
        band(
          footer,
          l10n?.invoiceTemplateFooterLabel ??
              'Footer band (payment terms, legal mentions)',
          key: 'invoice-template-footer',
        ),
      ],
    );
  }
}

/// What can be done with the open document (#474): a ready-made
/// report, an image, the instant preview, the PDF, the design exchange
/// (#864), a reset, and — in the sheet — Save.
class ReportTemplateActions extends StatelessWidget {
  const ReportTemplateActions({
    super.key,
    required this.doc,
    required this.busy,
    required this.showSave,
    required this.onPreset,
    required this.onInsertImage,
    required this.onQuickPreview,
    required this.onPdf,
    required this.onReset,
    required this.onSave,
    this.onExportDesign,
    this.onImportDesign,
  });

  final String doc;
  final bool busy, showSave;
  final ValueChanged<ReportPreset> onPreset;
  final VoidCallback onInsertImage, onQuickPreview, onReset, onSave;

  /// true downloads the PDF, false shares it.
  final ValueChanged<bool> onPdf;

  /// Both null when the design exchange is off.
  final VoidCallback? onExportDesign, onImportDesign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<ReportPreset>(
          key: const ValueKey('invoice-template-presets'),
          enabled: !busy,
          onSelected: onPreset,
          itemBuilder: (context) => [
            for (final preset in presetsForDoc(doc, l10n))
              PopupMenuItem(
                key: ValueKey('invoice-template-preset-${preset.id}'),
                value: preset,
                child: Text(preset.name),
              ),
          ],
          child: TextButton.icon(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n?.invoiceTemplatePresets ?? 'Templates'),
            // The menu opens from the surrounding button.
            onPressed: null,
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('invoice-template-image'),
          icon: const Icon(Icons.image_outlined),
          label: Text(l10n?.reportInsertImage ?? 'Insert image'),
          onPressed: busy ? null : onInsertImage,
        ),
        OutlinedButton.icon(
          key: const ValueKey('invoice-template-quick-preview'),
          icon: const Icon(Icons.bolt_outlined),
          label: Text(l10n?.invoiceTemplateQuickPreview ?? 'Quick preview'),
          onPressed: busy ? null : onQuickPreview,
        ),
        PopupMenuButton<bool>(
          key: const ValueKey('invoice-template-pdf'),
          enabled: !busy,
          onSelected: onPdf,
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const ValueKey('invoice-template-download'),
              value: true,
              child: Text(l10n?.invoiceTemplateDownload ?? 'Download PDF'),
            ),
            PopupMenuItem(
              key: const ValueKey('invoice-template-share'),
              value: false,
              child: Text(l10n?.invoiceTemplateShare ?? 'Share PDF'),
            ),
          ],
          child: OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n?.invoiceTemplatePreview ?? 'Preview'),
            onPressed: null,
          ),
        ),
        // #864 — the design leaves as a self-describing file and comes
        // back the same way, so it can be edited outside the app and
        // reviewed like source.
        if (onExportDesign != null || onImportDesign != null)
          ReportDesignExchangeButtons(
            onExport: busy ? null : onExportDesign,
            onImport: busy ? null : onImportDesign,
          ),
        TextButton.icon(
          key: const ValueKey('invoice-template-reset'),
          icon: const Icon(Icons.restart_alt),
          label: Text(l10n?.invoiceTemplateReset ?? 'Reset to default'),
          onPressed: busy ? null : onReset,
        ),
        if (showSave)
          FilledButton(
            key: const ValueKey('invoice-template-save'),
            onPressed: busy ? null : onSave,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
      ],
    );
  }
}
