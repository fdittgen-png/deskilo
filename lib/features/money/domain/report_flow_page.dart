// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:pdf/widgets.dart' as pw;

import 'report_page_footer.dart';

/// Shared pagination for letters and editable report covers. Header and
/// body flow down; the measured footer is anchored to the bottom margin.
pw.MultiPage reportFlowPage({
  required pw.PageTheme pageTheme,
  required String documentTitle,
  required String pageLabel,
  required pw.BuildListCallback body,
  required pw.BuildListCallback firstHeader,
  required pw.BuildListCallback footer,
  pw.BuildListCallback? continuation,
}) => pw.MultiPage(
  pageTheme: pageTheme,
  header: (context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    mainAxisSize: pw.MainAxisSize.min,
    children: context.pageNumber == 1
        ? firstHeader(context)
        : continuation?.call(context) ??
              [
                pw.Text(documentTitle, style: const pw.TextStyle(fontSize: 9)),
                pw.Divider(),
              ],
  ),
  footer: (context) =>
      reportPageFooter(context, content: footer(context), pageLabel: pageLabel),
  build: body,
);
