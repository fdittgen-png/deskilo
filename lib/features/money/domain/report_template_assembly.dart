// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice_pdf_template.dart';
import 'report_kind.dart';

/// The languages the report editor offers an overlay for (#496); '' is
/// the default template every language falls back to.
const List<String> reportTemplateLanguages = ['en', 'fr', 'de', 'es', 'it'];

/// The key of one unsaved band draft: the document alone in the default
/// language, `lang|doc` in an overlay.
String reportDraftKey(String lang, String doc) =>
    lang.isEmpty ? doc : '$lang|$doc';

/// The template the report editor saves: [stored] with every unsaved
/// edit folded in.
///
/// It starts FROM the stored template, so what this session did not
/// touch is kept as it was: the positioned layouts of other documents,
/// the address window, overlays in languages the editor does not offer,
/// and each document's continuation strip (#872), which the band
/// editors do not show and therefore never change.
///
/// [drafts] are band edits by [reportDraftKey]; [layoutDrafts] layouts
/// by kind id, '' removing one; [textDrafts] the owner's texts by
/// language, '' being the default language.
InvoicePdfTemplate assembleReportTemplate({
  required InvoicePdfTemplate stored,
  required Map<String, ReportBands> drafts,
  Map<String, String> layoutDrafts = const {},
  Map<String, Map<String, String>> textDrafts = const {},
  required int reminderLevels,
}) {
  final kinds = reportKinds(reminderLevels: reminderLevels);
  InvoicePdfTemplate fold(
    InvoicePdfTemplate template,
    ReportBands? Function(ReportKind kind) draftOf,
  ) {
    var next = template;
    for (final kind in kinds) {
      final draft = draftOf(kind);
      if (draft == null) continue;
      final kept = bandsOf(next, kind).continuation;
      next = withBands(next, kind, _withContinuation(draft, kept));
    }
    return next;
  }

  var template = fold(stored, (kind) => drafts[kind.id]);
  final defaultTexts = textDrafts[''];
  if (defaultTexts != null) template = template.copyWith(texts: defaultTexts);
  for (final entry in layoutDrafts.entries) {
    final kind = reportKindById(entry.key, reminderLevels: reminderLevels);
    if (kind != null) template = withLayout(template, kind, entry.value);
  }
  for (final lang in reportTemplateLanguages) {
    final edited = drafts.keys.any((key) => key.startsWith('$lang|'));
    final texts = textDrafts[lang];
    if (!edited && texts == null) continue;
    var overlay = fold(
      stored.translations[lang] ?? InvoicePdfTemplate.empty,
      (kind) => drafts[reportDraftKey(lang, kind.id)],
    );
    if (texts != null) overlay = overlay.copyWith(texts: texts);
    template = template.withTranslation(lang, overlay);
  }
  return template;
}

ReportBands _withContinuation(ReportBands bands, String continuation) =>
    bands.continuation.isNotEmpty || continuation.isEmpty
    ? bands
    : ReportBands(
        header: bands.header,
        body: bands.body,
        footer: bands.footer,
        continuation: continuation,
      );
