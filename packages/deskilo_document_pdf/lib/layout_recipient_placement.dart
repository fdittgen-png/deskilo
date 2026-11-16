// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'address_window.dart';

/// Where the recipient sits, and what that does to the header and the body.
/// A named convention takes the millimetres from the one place they live,
/// for the document's paper (#3981); an explicit frame is page-absolute by
/// definition.
class RecipientPlacement {
  RecipientPlacement(
    LayoutDocument document,
    PdfPageFormat format,
    double contentH,
    double marginTop,
    pw.ThemeData theme,
    ({String name, String address}) text,
  ) : name = text.name,
        address = text.address {
    final pageW = format.width, pageH = format.height;
    final recipient = document.recipient;
    final window = recipient?.window;
    final frame = recipient?.frame;
    final named = recipient != null &&
        !recipient.isOff &&
        (window != null || frame != null);
    final field = (window ?? AddressWindow.off).fieldOn(document.paper);
    fontSize = field.fontSizePt;
    left = frame?.x?.resolve(pageW) ??
        (window != null && window.isOn ? field.leftPt : 0.0);
    top = frame?.y?.resolve(pageH) ?? field.topPt;
    width = frame?.w?.resolve(pageW) ?? field.widthPt;
    height = frame?.h?.resolve(pageH) ?? field.heightPt;
    // A recipient that does not fit is not placed: the document is laid
    // out as when the window is off, and the recipient joins the flow.
    overflowed = named &&
        !addressFitsField(
          name: name,
          address: address,
          widthPt: width,
          heightPt: height,
          fontSize: fontSize,
          theme: theme,
        );
    windowOn = named && !overflowed;
    // The header owns the band above the field; the body resumes where
    // the design says, or where the convention does under a window, or
    // right after the header otherwise.
    headerH = document.header.height?.resolve(contentH) ??
        (windowOn
            ? (frame?.y != null ? top : field.senderLimitPt) - marginTop
            : null);
    // A body stated at the A4 convention's 90 mm under a named window
    // means "where the window convention resumes": on another paper that
    // is the paper's own line.
    final stated = document.body.y;
    final followsWindow = document.paper != Paper.a4 &&
        windowOn &&
        frame == null &&
        stated != null &&
        stated.unit == LengthUnit.mm &&
        stated.value == addressWindowFlowResumeMm;
    bodyTop = followsWindow
        ? field.flowResumePt
        : stated?.resolve(pageH) ?? (windowOn ? field.flowResumePt : null);
  }

  final String name, address;
  late final bool windowOn, overflowed;
  late final double left, top, width, height, fontSize;
  late final double? headerH, bodyTop;

  /// A recipient that does not fit its field, printed whole at the start of
  /// the flow (#3981); nothing when the field holds it.
  List<pw.Widget> recipientInFlow() => !overflowed
      ? const []
      : [
          addressWindowRecipient(name: name, address: address, fontSize: fontSize),
          pw.SizedBox(height: 12),
        ];
}
