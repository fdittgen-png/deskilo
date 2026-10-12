// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_template_sheet.dart';

// #2386 — part 2 of _ReportTemplateEditorState, split out of invoice_template_sheet.dart so no
// file holds the whole class.
extension _ReportTemplateEditorStatePart2 on _ReportTemplateEditorState {

  Widget _buildImpl(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wide = widget.asPage && MediaQuery.sizeOf(context).width >= 1000;
    final designExchange = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.reportDesignExchange);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asPage)
          Row(
            children: [
              Text(
                l10n.invoiceTemplateTitle,
                style: theme.textTheme.titleMedium,
              ),
              HelpDot(l10n.helpTopicReportEditor,
                anchor: HelpAnchor.reportsInvoiceTemplate,
              ),
            ],
          ),
        const SizedBox(height: 4),
        // #966 — the markup mode's guide: grouped fields with their
        // meaning, the line markup one sign per row, three ready-made
        // pieces, everything inserted at the caret. Collapsed until
        // asked for; the designer carries the fields in its own picker.
        if (!_visual)
          ReportMarkupGuide(
            textKeys: _currentTexts.keys.toList(),
            onInsert: _insertMarkup,
          ),
        const SizedBox(height: AppSpacing.sm),
        // #496 — one template per LANGUAGE: the default, plus an
        // overlay per language for readers in that language.
        ReportTemplateLanguageChips(
          selected: _lang,
          overridden: _overridden,
          canClear: _currentBands.hasBands,
          onSelect: _switchLang,
          onClear: () => _apply(ReportBands.empty),
        ),
        const SizedBox(height: AppSpacing.xs),
        // #472: one report per DOCUMENT — the invoice, and every
        // reminder level of the dunning rules.
        ReportTemplateDocChips(
          docs: _docs(l10n),
          selected: _doc,
          onSelect: _switchDoc,
        ),
        const SizedBox(height: AppSpacing.sm),
        // #488 — markup or WYSIWYG, same underlying bands.
        SegmentedButton<bool>(
          key: const ValueKey('invoice-template-mode'),
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.code),
              label: Text(l10n.reportEditorMarkup),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.design_services_outlined),
              label: Text(l10n.reportEditorVisual),
            ),
          ],
          selected: {_visual},
          onSelectionChanged: (selection) => _update(() {
            _visual = selection.first;
            _bumpEpoch();
          }),
        ),
        _editorArea(l10n, sideBySide: wide),
        const SizedBox(height: AppSpacing.md),
        // #474: pick a ready-made report, see it INSTANTLY, then
        // download or share the PDF — or save the bands.
        ReportTemplateActions(
          doc: _doc,
          busy: _busy,
          showSave: !widget.asPage,
          onPreset: (preset) async {
            if (!await _confirmReplace() || !mounted) return;
            _apply(preset.bands);
          },
          onInsertImage: _insertImage,
          onQuickPreview: _quickPreview,
          onPdf: (download) => _pdf(download: download),
          onReset: () async {
            if (!await _confirmReplace() || !mounted) return;
            _apply(defaultBandsForDoc(
                _doc, _lang.isEmpty ? l10n : l10nForLanguage(_lang)));
          },
          onSave: _save,
          // #864 — the design exchange, when the workspace has it.
          onExportDesign: designExchange ? _exportDesign : null,
          onImportDesign: designExchange ? _importDesign : null,
        ),
        // #875 — last in the column on purpose: the panel adds height
        // below every existing control, and moves none of them.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.reportLayouts)) ...[
          const SizedBox(height: AppSpacing.sm),
          ReportLayoutPanel(
            hasLayout: _layoutOfDoc != null,
            busy: _busy,
            onExport: _exportLayout,
            onImport: _importLayout,
            onRemove: () => _update(() => _layoutDrafts[_doc] = ''),
            onPreview: _previewLayout,
          ),
        ],
        // #880 — the owner's texts, after the layout panel for the same
        // reason: nothing above moves.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.reportTexts)) ...[
          const SizedBox(height: AppSpacing.sm),
          ReportTextsPanel(
            key: ValueKey('report-texts-$_lang'),
            language: _lang,
            texts: _textsFor(_lang),
            inherited: _lang.isEmpty ? const {} : _textsFor(''),
            onChanged: _setTexts,
          ),
        ],
      ],
    );
    if (!widget.asPage) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: content,
        ),
      );
    }
    // #822 — the page: a toolbar with undo / redo / save, the same
    // content underneath, and a guard on the way out.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmReportDiscard(context);
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // #1180 — the screen's own name was cut to "Report e…". The
          // help symbol sat INSIDE the title, taking 48 dp of it plus the
          // title's leading spacing, while every other screen puts its
          // help dot in the actions. Moved there, the title has room and
          // the app is one shape less inconsistent.
          title: Text(l10n.reportEditorTitle,
              overflow: TextOverflow.ellipsis),
          actions: [
            HelpDot(l10n.helpTopicReportEditor,
              anchor: HelpAnchor.reportsEditor,
            ),
            ReportHistoryControls(
              canUndo: _history.canUndo && !_busy,
              canRedo: _history.canRedo && !_busy,
              onUndo: _undo,
              onRedo: _redo,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('invoice-template-save'),
                onPressed: _busy ? null : _save,
                child: Text(l10n.commonSave),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
