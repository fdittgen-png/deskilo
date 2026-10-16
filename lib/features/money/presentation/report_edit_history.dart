// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_document_editor/deskilo_document_editor.dart';

import '../domain/invoice_pdf_template.dart';

/// #822 - undo / redo over ONE document's bands: the editor package's
/// linear history, told what the same bands are. Typing coalesces; a
/// structural change (a preset, a reset, a move) is always its own step.
class ReportEditHistory extends EditHistory<ReportBands> {
  ReportEditHistory(super.initial) : super(same: _sameBands);

  static bool _sameBands(ReportBands a, ReportBands b) =>
      a.header == b.header && a.body == b.body && a.footer == b.footer;
}
