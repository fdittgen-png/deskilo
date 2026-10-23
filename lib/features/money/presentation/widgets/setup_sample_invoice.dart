// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The sample invoice of the setup guide's Grow steps, rendered the way a
// real invoice's quick view renders: the workspace's own invoice design
// (the built-in one without it), its owner texts, the report engine, and
// the library images it names. It is marked as a sample above the page and
// where the number goes, and nothing is issued to draw it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../domain/report_data_sample.dart';
import '../../domain/report_facts.dart';
import '../invoice_documents.dart' show invoicePdfTemplateFor;
import '../report_defaults.dart';
import '../report_facts_of.dart';
import '../report_image_resolve.dart';
import '../report_strings_l10n.dart';
import 'report_page_style.dart';
import 'report_preview.dart';

/// The sample invoice through [look], or through the workspace's own
/// invoice design; a design that does not render falls back to the
/// built-in one, as the PDF does. [seller] is an identity being typed.
InvoiceReport setupSampleReport(
  BuildContext context,
  WidgetRef ref, {
  SellerDraft? seller,
  ReportBands? look,
}) {
  final l10n = context.l10n;
  final template = invoicePdfTemplateFor(ref);
  final data = withOwnerTexts(
    sampleInvoiceReportData(
      reportStringsFor(context),
      sampleInvoiceFactsOf(ref, seller: seller),
      (
        number: l10n.setupGrowSampleNumber,
        member: l10n.setupGrowSampleMember,
        line: l10n.setupGrowSampleLine,
      ),
    ),
    template.texts,
  );
  final builtIn = defaultBandsForDoc('invoice', l10n);
  final bands =
      look ??
      (template.invoiceBands.hasBands ? template.invoiceBands : builtIn);
  return renderReportBands(bands: bands, data: data) ??
      renderReportBands(bands: builtIn, data: data)!;
}

/// [report] on white paper at the page's own width, scaled down to the
/// pane, under a line that says it is a sample.
class SetupSampleSheet extends ConsumerStatefulWidget {
  const SetupSampleSheet({super.key, required this.report});

  final InvoiceReport report;

  @override
  ConsumerState<SetupSampleSheet> createState() => _SetupSampleSheetState();
}

class _SetupSampleSheetState extends ConsumerState<SetupSampleSheet> {
  late Future<Map<String, Uint8List>> _images = resolveReportImages(
    ref,
    widget.report,
  );

  @override
  void didUpdateWidget(SetupSampleSheet old) {
    super.didUpdateWidget(old);
    if (!setEquals(
      reportImageRefs(old.report),
      reportImageRefs(widget.report),
    )) {
      _images = resolveReportImages(ref, widget.report);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.setupGrowSampleBadge,
        key: const ValueKey('setup-sample-badge'),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      FutureBuilder<Map<String, Uint8List>>(
        future: _images,
        builder: (context, images) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: Container(
            key: const ValueKey('setup-sample-sheet'),
            width: ReportPage.width,
            color: ReportPage.paper,
            padding: ReportPage.margins,
            child: ReportBlocksView(
              report: widget.report,
              images: images.data ?? const {},
            ),
          ),
        ),
      ),
    ],
  );
}
