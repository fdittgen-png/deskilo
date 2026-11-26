// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the bytes of a till receipt for an ESC/POS receipt printer. A pure encoder: a [ReceiptPrint] (words and
// amounts already formatted by the caller, in the reader's language) and an [EscposProfile] (paper width, code page)
// in, the bytes a printer on raw TCP takes out. It decides nothing about the sale: a copy repeats the document and is
// marked as one, it never repeats a payment. No dependency: the commands are a handful of bytes.
import 'dart:typed_data';

/// The code page the printer is told to use (ESC t n) and the table that turns text into its bytes.
enum EscposCodePage {
  /// PC437 (the printer's usual default): é ß ñ à, no euro sign.
  cp437(0, _cp437),

  /// PC858: the Western European page with the euro sign.
  cp858(19, _cp858);

  const EscposCodePage(this.select, this._upper);

  /// The `n` of `ESC t n` that selects this page on an Epson-compatible printer.
  final int select;
  final String _upper;

  /// The byte of [rune] in this page, or null when the page has no such character.
  int? byteOf(int rune) {
    if (rune < 0x80) return rune;
    final at = _upper.runes.toList().indexOf(rune);
    return at < 0 ? null : 0x80 + at;
  }
}

// The upper halves (0x80-0xFF) of the two pages, one character per byte.
const _cp437 = 'ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ';
const _cp858 = 'ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜø£Ø×ƒáíóúñÑªº¿®¬½¼¡«»░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐└┴┬├─┼ãÃ╚╔╩╦╠═╬¤ðÐÊËÈ€ÍÎÏ┘┌█▄¦Ì▀ÓßÔÒõÕµþÞÚÛÙýÝ¯´­±‗¾¶§÷¸°¨·¹³²■ ';

/// What the printer is set up as: the paper (58 or 80 mm) and the code page.
class EscposProfile {
  const EscposProfile({this.paperMm = 80, this.codePage = EscposCodePage.cp858, this.cutAfter = true});

  final int paperMm;
  final EscposCodePage codePage;

  /// Whether the receipt ends with a cut (a printer without a cutter ignores it, but a tear-off one need not get it).
  final bool cutAfter;

  /// The characters one line holds in the printer's normal font: 48 on 80 mm paper, 32 on 58 mm.
  int get columns => paperMm >= 80 ? 48 : 32;
}

/// One line of the receipt: its words, the quantity when it is not one, and its amount.
class ReceiptPrintLine {
  const ReceiptPrintLine({required this.label, required this.amount, this.detail = ''});

  final String label;
  final String amount;

  /// A second, indented line under the label (for instance `0.35 kg`); empty when there is none.
  final String detail;
}

/// A tender as the receipt says it: its words and its amount.
class ReceiptPrintTender {
  const ReceiptPrintTender({required this.label, required this.amount});

  final String label;
  final String amount;
}

/// The receipt as it is printed, every word and amount already in the reader's language and currency.
class ReceiptPrint {
  const ReceiptPrint({
    required this.business,
    required this.title,
    required this.issuedAt,
    required this.lines,
    required this.totalLabel,
    required this.total,
    required this.taxLabel,
    required this.tax,
    required this.tenders,
    this.changeLabel = '',
    this.change = '',
    this.copyMark = '',
    this.footer = '',
    this.qr = '',
  });

  final String business;

  /// For instance `Receipt R-00001`.
  final String title;
  final String issuedAt;
  final List<ReceiptPrintLine> lines;
  final String totalLabel;
  final String total;
  final String taxLabel;
  final String tax;
  final List<ReceiptPrintTender> tenders;
  final String changeLabel;
  final String change;

  /// The word that marks a reprint (`COPY`); empty on the original. A copy prints the same document under it.
  final String copyMark;
  final String footer;

  /// What the QR code carries (for instance the address that shows the receipt); empty for none.
  final String qr;
}

const _esc = 0x1B;
const _gs = 0x1D;
const _lf = 0x0A;

/// The bytes of [receipt] for a printer set up as [profile].
Uint8List encodeReceipt(ReceiptPrint receipt, EscposProfile profile) {
  final out = _Bytes(profile);
  final cols = profile.columns;
  out
    ..raw([_esc, 0x40]) // initialise
    ..raw([_esc, 0x74, profile.codePage.select])
    ..align(1);
  if (receipt.copyMark.isNotEmpty) out.line(receipt.copyMark, bold: true, double: true);
  out
    ..line(receipt.business, bold: true)
    ..line(receipt.title)
    ..line(receipt.issuedAt)
    ..align(0)
    ..line('-' * cols);
  for (final l in receipt.lines) {
    out.pair(l.label, l.amount, cols);
    if (l.detail.isNotEmpty) out.line('  ${l.detail}');
  }
  out
    ..line('-' * cols)
    ..pair(receipt.taxLabel, receipt.tax, cols)
    ..pair(receipt.totalLabel, receipt.total, cols, bold: true, double: true);
  for (final t in receipt.tenders) {
    out.pair(t.label, t.amount, cols);
  }
  if (receipt.change.isNotEmpty) out.pair(receipt.changeLabel, receipt.change, cols);
  if (receipt.footer.isNotEmpty || receipt.qr.isNotEmpty) out.align(1);
  if (receipt.footer.isNotEmpty) out.line('\n${receipt.footer}');
  if (receipt.qr.isNotEmpty) out.qr(receipt.qr);
  out.feed(profile.cutAfter ? 3 : 4);
  if (profile.cutAfter) out.raw([_gs, 0x56, 0x42, 0x03]); // feed and partial cut
  return out.take();
}

/// The drawer-kick command (`ESC p`): pin 2 (0) or pin 5 (1), a pulse of [onMs] then [offMs] (2 ms units on the wire).
Uint8List drawerKick({int pin = 0, int onMs = 50, int offMs = 500}) =>
    Uint8List.fromList([_esc, 0x70, pin.clamp(0, 1), (onMs ~/ 2).clamp(0, 255), (offMs ~/ 2).clamp(0, 255)]);

class _Bytes {
  _Bytes(this.profile);

  final EscposProfile profile;
  final _b = BytesBuilder();

  void raw(List<int> bytes) => _b.add(bytes);

  void align(int n) => raw([_esc, 0x61, n]);

  void feed(int n) => raw([_esc, 0x64, n]);

  Uint8List take() => _b.toBytes();

  List<int> text(String s) {
    final out = <int>[];
    for (final r in s.runes) {
      out.add(profile.codePage.byteOf(_plain(r)) ?? 0x3F);
    }
    return out;
  }

  /// Typographic marks the pages lack, as their plain neighbours.
  int _plain(int r) => switch (r) {
    0x2018 || 0x2019 => 0x27,
    0x201C || 0x201D => 0x22,
    0x2013 || 0x2014 => 0x2D,
    0x00A0 || 0x202F => 0x20,
    _ => r,
  };

  void _style({bool bold = false, bool double = false}) {
    raw([_esc, 0x45, if (bold) 1 else 0]);
    raw([_gs, 0x21, if (double) 0x11 else 0]);
  }

  void line(String s, {bool bold = false, bool double = false}) {
    _style(bold: bold, double: double);
    for (final part in s.split('\n')) {
      raw(text(part));
      raw([_lf]);
    }
    if (bold || double) _style();
  }

  /// [left] and [right] on one line, the right one flush right; a left that does not fit wraps on the lines above.
  /// In double width a character takes two columns.
  void pair(String left, String right, int cols, {bool bold = false, bool double = false}) {
    final width = double ? cols ~/ 2 : cols;
    final room = width - right.runes.length - 1;
    final parts = _wrap(left, room < 4 ? width : room);
    _style(bold: bold, double: double);
    for (var i = 0; i < parts.length; i++) {
      final last = i == parts.length - 1;
      var row = parts[i];
      if (last) {
        final pad = width - row.runes.length - right.runes.length;
        row = '$row${' ' * (pad < 1 ? 1 : pad)}$right';
      }
      raw(text(row));
      raw([_lf]);
    }
    if (bold || double) _style();
  }

  List<String> _wrap(String s, int width) {
    final out = <String>[];
    var rest = s.runes.toList();
    if (rest.isEmpty) return [''];
    while (rest.length > width) {
      var cut = width;
      final space = rest.sublist(0, width + 1).lastIndexOf(0x20);
      if (space > 0) cut = space;
      out.add(String.fromCharCodes(rest.sublist(0, cut)).trimRight());
      rest = rest.sublist(cut).skipWhile((c) => c == 0x20).toList();
    }
    out.add(String.fromCharCodes(rest));
    return out;
  }

  /// A native QR code: model 2, module size 4, error correction M (the printer draws it).
  void qr(String data) {
    final body = text(data);
    final n = body.length + 3;
    raw([_gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]); // model 2
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04]); // module size
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]); // error correction M
    raw([_gs, 0x28, 0x6B, n & 0xFF, n >> 8, 0x31, 0x50, 0x30, ...body]); // store
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // print
    raw([_lf]);
  }
}
