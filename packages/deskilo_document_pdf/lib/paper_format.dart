// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 - a paper as the PDF library measures it. A4 is the library's own
// A4, so a document printed on A4 keeps its bytes.
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:pdf/pdf.dart';

/// The page format of [paper].
PdfPageFormat pdfPageFormatOf(Paper paper) => switch (paper) {
  Paper.a4 => PdfPageFormat.a4,
  Paper.letter => PdfPageFormat.letter,
};
