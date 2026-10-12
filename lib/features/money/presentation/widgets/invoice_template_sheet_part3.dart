// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_template_sheet.dart';


/// The invoice REPORT editor (#454, rebuilt as a banded reporting tool
/// in #470): three Liquid bands — header, body with the lines, footer —
/// with a syntax cheat-sheet, a reset to the built-in layout as a
/// working starting point, and a live preview (rendered as a COPY of
/// the newest invoice through the UNSAVED bands). The sheet says the
/// one thing an owner must never misread: this edits the PDF only,
/// never the legal XML.
///
/// #822 — with `reportDesigner` on, the editor is a full-screen ROUTE
/// (`/report-editor`) rather than a sheet; the same widget serves both.
Future<void> showInvoiceTemplateSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.reportDesigner)) {
    // The route when a router is there (deep-linkable); the same page
    // where the editor is hosted without one.
    await openLocation<void>(
      context,
      '/report-editor',
      orBuild: (_) => const ReportEditorScreen(),
    );
    return;
  }
  final template = await ref.read(invoicePdfTemplateProvider.future);
  if (!context.mounted) return;
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReportTemplateEditor(initial: template),
  );
}

/// The template editor itself — the sheet's content, or (#822) the
/// whole page with a toolbar, undo/redo, a discard guard and, on a wide
/// screen, design and preview side by side.
class ReportTemplateEditor extends ConsumerStatefulWidget {
  const ReportTemplateEditor({
    super.key,
    required this.initial,
    this.asPage = false,
  });

  final InvoicePdfTemplate initial;
  final bool asPage;

  @override
  ConsumerState<ReportTemplateEditor> createState() =>
      _ReportTemplateEditorState();
}
