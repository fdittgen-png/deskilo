// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish return (Modelo 303) as a file (see `vat_filing_files.dart`).
import '../../../core/time/date_text.dart';
import 'vat_declaration.dart';
import 'vat_filing_es_layout.dart';
import 'vat_filing_terms.dart';

/// The Modelo 303 of [declaration] as the fixed-width text of the AEAT's
/// "diseño de registro": the envelope (`<T3030…>`, the `<AUX>` block left
/// blank for a developer the AEAT has not registered), page 01 with the
/// liquidación of the régimen general and page 03 with the información
/// adicional and the result.
///
/// The casillas come from the boxes `vatFormBoxes('ES', …)` fills, so the
/// file and the PDF agree. The space files to the State alone (not to a
/// foral administration), in the régimen general only, without prorrata or
/// insolvency, and compensates a negative result (tipo `C`); a refund (`D`)
/// needs the bank page, which the owner completes in the Sede. A sale at a
/// rate the form has no casilla for refuses the file rather than leave it
/// out. Amounts in cents, 15 integer and 2 decimal positions.
String aeat303File({
  required VatDeclaration declaration,
  required String vatId,
  required String name,
  required bool onReceipts,
  required VatFilingFacts facts,
}) {
  final period = monthOrQuarterOf(declaration);
  final nif = _nif(vatId);
  if (nif == null) {
    throw const VatFilingFileException(VatFilingFileProblem.vatNumber);
  }
  final last = period.month == 12 || period.quarter == 4;
  if (last && facts.immediateSupply) {
    throw const VatFilingFileException(VatFilingFileProblem.annualVolume);
  }
  final boxes = <String, int>{};
  for (final box in vatFormBoxes(
    'ES',
    declaration.lines,
    periodEnd: declaration.periodEnd,
  )) {
    final mapped = box.baseKey.isNotEmpty || box.taxKey.isNotEmpty;
    if (!mapped && (box.netCents != 0 || box.vatCents != 0)) {
      throw const VatFilingFileException(VatFilingFileProblem.unmappedBox);
    }
    if (box.hasBase && box.baseKey.isNotEmpty) {
      boxes[box.baseKey] = box.netCents;
    }
    if (box.hasTax && box.taxKey.isNotEmpty) {
      boxes[box.taxKey] = box.vatCents;
    }
  }
  // The result of a space taxed by the State alone: [64] = [46], all of it
  // attributable ([65] = 100 %, [66]), nothing carried in, so [69] = [71].
  final result = boxes['46'] ?? 0;
  boxes
    ..['64'] = result
    ..['65'] = _fullShare
    ..['66'] = result
    ..['69'] = result
    ..['71'] = result;
  final year = '${declaration.periodStart.year}';
  final code = period.month != null
      ? twoDigits(period.month!)
      : '${period.quarter}T';
  String yesNo({required bool yes}) => yes ? '1' : '2';
  // Page 01's identification fields, by their number in the design.
  final identification = <int, String>{
    6: result > 0 ? 'I' : (result < 0 ? 'C' : 'N'),
    7: nif,
    8: _text(name),
    9: year,
    10: code,
    11: '2', // no import VAT pending with a foral administration
    12: yesNo(yes: facts.monthlyRefund),
    13: '3', // the régimen general only
    14: '2', // not a joint return
    15: yesNo(yes: onReceipts),
    16: yesNo(yes: facts.cashCriterionRecipient),
    17: '2', // no special prorrata (Nota 6)
    18: '2',
    19: '2', // not in insolvency proceedings
    22: yesNo(yes: facts.immediateSupply),
    // Nota 4 and Nota 3: '0' before the last period; on the last one a
    // space outside SII is not exonerated from the 390.
    23: last ? '2' : '0',
    24: '0',
    // Nota 8: '0' for the quarters and January, else '2' (no fuel deliveries).
    25: period.quarter != null || period.month == 1 ? '0' : '2',
  };
  final page03 = <int, String>{30: declaration.lines.isEmpty ? 'X' : ''};
  final pages = [
    _page(aeat303Pages['01000']!, boxes, identification),
    _page(aeat303Pages['03000']!, boxes, page03),
  ].join();
  final header = '<T3030$year${code}0000>';
  // The <AUX> block: positions 23-322 reserved or for a registered
  // developer (version, NIF); left blank.
  final aux = '<AUX>${' ' * 300}</AUX>';
  return '$header$aux$pages</T3030$year${code}0000>';
}

/// [65]: 100 % attributable to the State, 3 integer and 2 decimal positions.
const _fullShare = 10000;

String _page(
  List<Aeat303Field> fields,
  Map<String, int> boxes,
  Map<int, String> values,
) {
  final out = StringBuffer();
  for (final f in fields) {
    final constant = f.constant;
    final box = f.box;
    if (constant != null) {
      out.write(constant);
    } else if (box != null) {
      out.write(_amount(boxes[box] ?? 0, f));
    } else {
      final value = values[f.number] ?? '';
      out.write(
        f.kind == Aeat303Kind.alphanumeric || value.isEmpty
            ? value.padRight(f.length).substring(0, f.length)
            : value.padLeft(f.length, '0'),
      );
    }
  }
  return out.toString();
}

/// An amount in cents in its field: zero-padded; a negative one starts
/// with `N` in a signed field and refuses the file in an unsigned one.
String _amount(int cents, Aeat303Field f) {
  if (cents < 0) {
    if (f.kind != Aeat303Kind.signed) {
      throw const VatFilingFileException(VatFilingFileProblem.negativeAmount);
    }
    return 'N${(-cents).toString().padLeft(f.length - 1, '0')}';
  }
  return cents.toString().padLeft(f.length, '0');
}

/// The nine characters of a Spanish NIF, with or without its ES prefix.
String? _nif(String vatId) {
  var id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  if (id.startsWith('ES')) id = id.substring(2);
  return RegExp(r'^[A-Z0-9]\d{7}[A-Z0-9]$').hasMatch(id) ? id : null;
}

/// A name as an `An` field takes it: capitals, digits and blanks, the
/// accents of Spanish dropped but Ñ and Ç kept (the file is ISO-8859-1).
String _text(String raw) {
  const plain = {
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ä': 'A',
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ô': 'O',
    'Ö': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Û': 'U',
    'Ü': 'U',
  };
  final upper = raw.toUpperCase().split('').map((c) => plain[c] ?? c).join();
  return upper.replaceAll(RegExp('[^A-Z0-9ÑÇ]+'), ' ').trim();
}
