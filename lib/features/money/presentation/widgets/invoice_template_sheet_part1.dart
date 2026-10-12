// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_template_sheet.dart';

// #2386 — part 1 of _ReportTemplateEditorState, split out of invoice_template_sheet.dart so no
// file holds the whole class.
extension _ReportTemplateEditorStatePart1 on _ReportTemplateEditorState {

  Map<String, String> _textsFor(String lang) =>
      _textDrafts[lang] ??
      (lang.isEmpty
          ? widget.initial.texts
          : widget.initial.translations[lang]?.texts ?? const {});

  void _setTexts(Map<String, String> texts) => _update(() {
        _textDrafts[_lang] = texts;
        _dirty = true;
        _bumpEpoch();
      });

  void _bumpEpoch() {
    _visualEpoch++;
    _designerKey = GlobalKey<ReportPageDesignerState>();
  }

  /// #822 — every controller change lands in the history (typing
  /// coalesces there); a structural change records as its own step.
  void _record({bool step = false}) {
    if (_restoring) return;
    final before = _history.length;
    _history.push(_currentBands, at: ref.read(clockProvider).now(), step: step);
    if (_history.length != before || step) _dirty = true;
    if (mounted) _update(() {});
  }

  void _apply(ReportBands bands, {bool step = true}) {
    _restoring = true;
    _header.text = bands.header;
    _body.text = bands.body;
    _footer.text = bands.footer;
    _restoring = false;
    _update(_bumpEpoch);
    if (step) _record(step: true);
  }

  void _undo() {
    if (!_history.canUndo) return;
    final bands = _history.undo();
    _dirty = true;
    _apply(bands, step: false);
  }

  void _redo() {
    if (!_history.canRedo) return;
    final bands = _history.redo();
    _dirty = true;
    _apply(bands, step: false);
  }


  /// The stored bands of document [doc] in the edited LANGUAGE, before
  /// any unsaved edit. In a language overlay, empty = inherits default.
  ReportBands _storedBands(String doc, {String? lang}) => _storedBandsOf(
      (lang ?? _lang).isEmpty
          ? widget.initial
          : (widget.initial.translations[lang ?? _lang] ??
              InvoicePdfTemplate.empty),
      doc);

  /// #864 — one registry answers this now. The switch this replaces
  /// fell through to "then it must be a reminder", so an unknown id
  /// silently edited level 1 instead of failing.
  ReportBands _storedBandsOf(InvoicePdfTemplate template, String doc) {
    final kind = reportKindById(doc, reminderLevels: _reminderLevels);
    return kind == null ? ReportBands.empty : bandsOf(template, kind);
  }

  /// #822 — whether language [lang] carries its OWN bands for the
  /// current document (unsaved edits included).
  bool _overridden(String lang) => lang == _lang
      ? _currentBands.hasBands
      : (_drafts[reportDraftKey(lang, _doc)] ?? _storedBands(_doc, lang: lang))
          .hasBands;

  void _switchDoc(String doc) {
    if (doc == _doc) return;
    _drafts[reportDraftKey(_lang, _doc)] = _currentBands;
    _doc = doc;
    _apply(_drafts[reportDraftKey(_lang, doc)] ?? _storedBands(doc), step: false);
  }

  /// #496 — switch the edited template LANGUAGE, keeping the document.
  void _switchLang(String lang) {
    if (lang == _lang) return;
    _drafts[reportDraftKey(_lang, _doc)] = _currentBands;
    _lang = lang;
    _apply(_drafts[reportDraftKey(lang, _doc)] ?? _storedBands(_doc),
        step: false);
  }

  /// The full template with every unsaved edit folded in (#496).
  InvoicePdfTemplate _assemble(int maxLevels) {
    _drafts[reportDraftKey(_lang, _doc)] = _currentBands;
    return assembleReportTemplate(
      stored: widget.initial,
      drafts: _drafts,
      layoutDrafts: _layoutDrafts,
      textDrafts: _textDrafts,
      reminderLevels: maxLevels,
    );
  }

  /// #864 — write the open design out. The file names the report it
  /// belongs to, so importing it into another one is refused rather
  /// than silently retargeted.
  Future<void> _exportLayout() async {
    final kind = reportKindById(_doc, reminderLevels: _reminderLevels);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final xml = _layoutOfDoc;
    if (kind == null || workspace == null || xml == null) return;
    await exportReportLayout(context, ref,
        kind: kind,
        language: _lang,
        workspaceName: workspace.name,
        layoutXml: xml,
        texts: _currentTexts,
        exportedAt: ref.read(clockProvider).now());
  }

  Future<void> _importLayout() async {
    final kind = reportKindById(_doc, reminderLevels: _reminderLevels);
    if (kind == null) return;
    final file = await importReportLayout(context, ref,
        kind: kind, reminderLevels: _reminderLevels);
    if (file == null || !mounted) return;
    _update(() {
      _layoutDrafts[_doc] = file.layoutXml;
      // #880 — the file's texts land on the language being edited.
      if (file.texts.isNotEmpty) {
        _textDrafts[_lang] = {..._textsFor(_lang), ...file.texts};
      }
    });
    AppSnack.success(context,
        context.l10n.reportLayoutImported);
  }

  Future<void> _previewLayout() async {
    final xml = _layoutOfDoc;
    if (xml == null) return;
    await showLayoutQuickPreview(context, ref,
        layoutXml: xml,
        data: withOwnerTexts(
            liveReportData(context, ref, _doc) ?? sampleReportData(context.l10n),
            _currentTexts));
  }

  Future<void> _exportDesign() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    final kind = reportKindById(_doc, reminderLevels: _reminderLevels);
    if (workspace == null || kind == null) return;
    await exportReportDesign(
      context,
      ref,
      kind: kind,
      language: _lang,
      workspaceName: workspace.name,
      bands: _currentBands,
      exportedAt: ref.read(clockProvider).now(),
    );
  }

  /// #864 — read one back into the document being edited. It lands in
  /// the editor, not in the workspace: nothing is stored until Save,
  /// which is what makes an import reviewable before it counts.
  Future<void> _importDesign() async {
    final l10n = context.l10n;
    final kind = reportKindById(_doc, reminderLevels: _reminderLevels);
    if (kind == null) return;
    if (!await _confirmReplace() || !mounted) return;
    final bands = await importReportDesign(
      context,
      ref,
      kind: kind,
      reminderLevels: _reminderLevels,
    );
    if (bands == null || !mounted) return;
    _apply(bands);
    AppSnack.info(
        context,
        l10n.reportDesignImported);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final levels =
        (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
            .levels;
    _update(() => _busy = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setInvoicePdfTemplate(workspace.id, _assemble(levels));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'set invoice template failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      _update(() => _busy = false);
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      return;
    }
    ref.invalidate(invoicePdfTemplateProvider);
    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n.invoiceTemplateSaved,
      replace: true,
    );
  }

  /// #822 — presets and reset REPLACE a layout: ask when there is one.
  Future<bool> _confirmReplace() async =>
      !_currentBands.hasBands || await confirmReportReplace(context);

  /// INSTANT preview (#474): the report engine's output rendered as
  /// widgets — real newest-invoice data when one exists, simulated
  /// sample data otherwise. No PDF round-trip.

  Future<void> _quickPreview() async {
    final l10n = context.l10n;
    final live = liveReportData(context, ref, _doc);
    final simulated = live == null;
    final data = withOwnerTexts(live ?? sampleReportData(l10n), _currentTexts);
    final bands = _currentBands.hasBands
        ? _currentBands
        : defaultBandsForDoc(_doc, l10n);
    final report = renderReportBands(bands: bands, data: data);
    final images = await resolveReportImages(ref, report);
    if (!mounted) return;
    if (report == null) {
      // #822 — the engine's own message, not a generic shrug.
      final why = reportBandsError(bands: bands, data: data) ?? '';
      AppSnack.error(
        context,
        l10n.reportDesignerError(why),
      );
      return;
    }
    await showReportQuickPreview(context,
        report: report, simulated: simulated, images: images);
  }

  /// Renders the selected DOCUMENT through the UNSAVED bands as a PDF —
  /// the invoice as a watermarked copy, a reminder as its letter — and
  /// either DOWNLOADS it or hands it to the share sheet (#474).
  Future<void> _pdf({required bool download}) async {
    final l10n = context.l10n;
    final invoices = ref.read(invoicesProvider).value ?? const [];
    if (invoices.isEmpty) {
      AppSnack.info(
        context,
        l10n.invoiceTemplateNoPreview,
        replace: true,
      );
      return;
    }
    _update(() => _busy = true);
    try {
      final l10nSync = context.l10n;
      final ({List<int> bytes, String fileName}) pdf;
      if (_doc == 'invoice' || _doc == 'proforma') {
        final invoicePdf = await buildInvoicePdfFile(
          context,
          invoices.first,
          proforma: _doc == 'proforma',
          copy: true,
          template: _doc == 'proforma'
              ? InvoicePdfTemplate(proforma: _currentBands)
              : InvoicePdfTemplate(
                  header: _currentBands.header,
                  body: _currentBands.body,
                  footer: _currentBands.footer,
                  // #872 — or the preview drops the page-2 strip.
                  continuation: _currentBands.continuation,
                ),
          workspace: ref.read(currentWorkspaceProvider).value,
          reportImage: (name) =>
              ref.read(reportImageBytesProvider(name).future),
        );
        pdf = (bytes: invoicePdf.bytes, fileName: invoicePdf.fileName);
      } else if (_doc == 'statement' ||
          reportKindById(_doc, reminderLevels: _reminderLevels)?.slot
              is ReportDocSlot) {
        // The letter documents: my own live data, or the sample.
        final data = withOwnerTexts(
            liveReportData(context, ref, _doc) ?? sampleReportData(l10nSync), _currentTexts);
        final bands = _currentBands.hasBands
            ? _currentBands
            : defaultBandsForDoc(_doc, l10nSync);
        final report = renderReportBands(bands: bands, data: data) ??
            renderReportBands(
                bands: defaultBandsForDoc(_doc, l10nSync), data: data)!;
        Future<pw.Font> font(String asset) async =>
            pw.Font.ttf(await rootBundle.load(asset));
        final bytes = await buildBandedLetterPdf(
          report: report,
          reportImages: await resolveReportImages(ref, report),
          pageLabel: l10nSync.invoicePdfPage,
          documentTitle: l10nSync.billPdfTitle,
          baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
          boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
        );
        pdf = (
          bytes: bytes,
          fileName:
              '${safeFileSlug(l10nSync.billPdfTitle)}.pdf',
        );
      } else {
        final letter = await buildReminderPdfFile(
          context,
          ref,
          invoices.first,
          level: int.tryParse(_doc.substring(1)) ?? 1,
          draftBands: _currentBands,
        );
        pdf = (bytes: letter.bytes, fileName: letter.fileName);
      }
      if (!mounted) return;
      if (download) {
        await savePdfToDownloads(
          context,
          ref,
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
        );
      } else {
        await ref.read(fileSharerProvider)(
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
          mimeType: 'application/pdf',
        );
      }
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'template pdf failed',
          error: e, stackTrace: st);
      if (mounted) {
        AppSnack.error(
          context,
          l10n.workspaceGenericError,
        );
      }
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _insertImage() async {
    final name = await showReportImagePicker(context, ref);
    if (name == null || !mounted) return;
    final designer = _designerKey.currentState;
    if (_visual && designer != null) {
      // #822 — after the selected element, or at the header's end.
      designer.insertImage(name);
      return;
    }
    // Appended to the band a logo most likely belongs to; move it
    // anywhere afterwards.
    _header.text =
        _header.text.isEmpty ? '![$name]' : '${_header.text}\n![$name]';
    _update(_bumpEpoch);
  }

  void _insertMarkup(String markup) {
    final controller = _focusedBand ?? _header;
    controller.value = insertMarkupAt(controller.value, markup);
  }

  /// #864 — the chips come from the registry, so a report kind added
  /// there appears here without this list being remembered.
  List<(String, String)> _docs(AppLocalizations l10n) => [
        for (final kind in reportKinds(reminderLevels: _reminderLevels))
          (kind.id, reportKindLabel(l10n, kind)),
      ];

  Widget _editorArea(AppLocalizations l10n, {required bool sideBySide}) {
    if (_visual) {
      // #548 — the page-true design surface: one A4 page, the
      // document's margins, band strips, page-break guides, zoom, and
      // a Design ↔ Preview toggle (or both pages at once — #822).
      return ReportPageDesigner(
        key: _designerKey,
        header: _header,
        body: _body,
        footer: _footer,
        headerLabel: l10n.invoiceTemplateHeaderLabel,
        bodyLabel: l10n.invoiceTemplateBodyLabel,
        footerLabel: l10n.invoiceTemplateFooterLabel,
        editorKeyPrefix: 'visual-$_doc-$_visualEpoch',
        previewData: () =>
            withOwnerTexts(liveReportData(context, ref, _doc) ?? sampleReportData(l10n), _currentTexts),
        textKeys: _currentTexts.keys.toList(),
        sideBySide: sideBySide,
      );
    }
    return ReportMarkupBands(
      header: _header,
      body: _body,
      footer: _footer,
      onFocus: (band) => _focusedBand = band,
    );
  }
}
