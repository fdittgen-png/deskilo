// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The fields of the Modelo 303 file, as the AEAT's "diseño de registro"
// lays them out (DR303e26v101.xlsx, for returns from the 2026 exercise on;
// shipped verbatim under test/fixtures/vat_filing/es_303/, which the
// layout test reads row by row). A field is its number, its first
// position (1-based), its length, its kind and either the constant the
// design prescribes or the casilla it carries.
import 'package:meta/meta.dart';

/// The design's four kinds of field.
enum Aeat303Kind {
  /// `A` and `An`: letters, digits and blanks, left-aligned, blank-padded.
  alphanumeric,

  /// `Num`: an unsigned number, right-aligned, zero-padded.
  unsigned,

  /// `N`: a number whose negative value starts with `N`.
  signed,
}

const _an = Aeat303Kind.alphanumeric;
const _num = Aeat303Kind.unsigned;
const _signed = Aeat303Kind.signed;

@immutable
class Aeat303Field {
  const Aeat303Field(
    this.number,
    this.position,
    this.length,
    this.kind, {
    this.constant,
    this.box,
  });

  /// The row of the design (`Nº`).
  final int number;
  final int position;
  final int length;
  final Aeat303Kind kind;

  /// What the design fixes for the field (`Constante "…"`).
  final String? constant;

  /// The casilla of the form the field carries (`[01]`).
  final String? box;
}

/// The pages the file writes, by their page code: 01 (liquidación) and 03
/// (información adicional and resultado). Pages 04 and 05 are left out
/// when they hold nothing, as the design says; page 02 is the régimen
/// simplificado, which a DesKilo space does not apply.
const aeat303Pages = {'01000': _page01, '03000': _page03};

/// Page 01 of the 2026 design (sheet DP30301).
const _page01 = [
  Aeat303Field(1, 1, 2, _an, constant: '<T'),
  Aeat303Field(2, 3, 3, _num, constant: '303'),
  Aeat303Field(3, 6, 5, _num, constant: '01000'),
  Aeat303Field(4, 11, 1, _an, constant: '>'),
  Aeat303Field(5, 12, 1, _an),
  Aeat303Field(6, 13, 1, _an),
  Aeat303Field(7, 14, 9, _an),
  Aeat303Field(8, 23, 80, _an),
  Aeat303Field(9, 103, 4, _num),
  Aeat303Field(10, 107, 2, _an),
  Aeat303Field(11, 109, 1, _num),
  Aeat303Field(12, 110, 1, _num),
  Aeat303Field(13, 111, 1, _num),
  Aeat303Field(14, 112, 1, _num),
  Aeat303Field(15, 113, 1, _num),
  Aeat303Field(16, 114, 1, _num),
  Aeat303Field(17, 115, 1, _num),
  Aeat303Field(18, 116, 1, _num),
  Aeat303Field(19, 117, 1, _num),
  Aeat303Field(20, 118, 8, _an),
  Aeat303Field(21, 126, 1, _an),
  Aeat303Field(22, 127, 1, _num),
  Aeat303Field(23, 128, 1, _num),
  Aeat303Field(24, 129, 1, _num),
  Aeat303Field(25, 130, 1, _num),
  Aeat303Field(26, 131, 17, _num, box: '150'),
  Aeat303Field(27, 148, 5, _num, constant: '00000'),
  Aeat303Field(28, 153, 17, _num, box: '152'),
  Aeat303Field(29, 170, 17, _num, box: '165'),
  Aeat303Field(30, 187, 5, _num, constant: '00000'),
  Aeat303Field(31, 192, 17, _num, box: '167'),
  Aeat303Field(32, 209, 17, _num, box: '01'),
  Aeat303Field(33, 226, 5, _num, constant: '00400'),
  Aeat303Field(34, 231, 17, _num, box: '03'),
  Aeat303Field(35, 248, 17, _num, box: '153'),
  Aeat303Field(36, 265, 5, _num, constant: '00000'),
  Aeat303Field(37, 270, 17, _num, box: '155'),
  Aeat303Field(38, 287, 17, _num, box: '04'),
  Aeat303Field(39, 304, 5, _num, constant: '01000'),
  Aeat303Field(40, 309, 17, _num, box: '06'),
  Aeat303Field(41, 326, 17, _num, box: '07'),
  Aeat303Field(42, 343, 5, _num, constant: '02100'),
  Aeat303Field(43, 348, 17, _num, box: '09'),
  Aeat303Field(44, 365, 17, _num, box: '10'),
  Aeat303Field(45, 382, 17, _num, box: '11'),
  Aeat303Field(46, 399, 17, _num, box: '12'),
  Aeat303Field(47, 416, 17, _num, box: '13'),
  Aeat303Field(48, 433, 17, _signed, box: '14'),
  Aeat303Field(49, 450, 17, _signed, box: '15'),
  Aeat303Field(50, 467, 17, _num, box: '156'),
  Aeat303Field(51, 484, 5, _num, constant: '00175'),
  Aeat303Field(52, 489, 17, _num, box: '158'),
  Aeat303Field(53, 506, 17, _num, box: '168'),
  Aeat303Field(54, 523, 5, _num, constant: '00050'),
  Aeat303Field(55, 528, 17, _num, box: '170'),
  Aeat303Field(56, 545, 17, _num, box: '16'),
  Aeat303Field(57, 562, 5, _num, constant: '00000'),
  Aeat303Field(58, 567, 17, _num, box: '18'),
  Aeat303Field(59, 584, 17, _num, box: '19'),
  Aeat303Field(60, 601, 5, _num, constant: '00140'),
  Aeat303Field(61, 606, 17, _num, box: '21'),
  Aeat303Field(62, 623, 17, _num, box: '22'),
  Aeat303Field(63, 640, 5, _num, constant: '00520'),
  Aeat303Field(64, 645, 17, _num, box: '24'),
  Aeat303Field(65, 662, 17, _signed, box: '25'),
  Aeat303Field(66, 679, 17, _signed, box: '26'),
  Aeat303Field(67, 696, 17, _signed, box: '27'),
  Aeat303Field(68, 713, 17, _num, box: '28'),
  Aeat303Field(69, 730, 17, _num, box: '29'),
  Aeat303Field(70, 747, 17, _num, box: '30'),
  Aeat303Field(71, 764, 17, _num, box: '31'),
  Aeat303Field(72, 781, 17, _num, box: '32'),
  Aeat303Field(73, 798, 17, _num, box: '33'),
  Aeat303Field(74, 815, 17, _num, box: '34'),
  Aeat303Field(75, 832, 17, _num, box: '35'),
  Aeat303Field(76, 849, 17, _num, box: '36'),
  Aeat303Field(77, 866, 17, _num, box: '37'),
  Aeat303Field(78, 883, 17, _num, box: '38'),
  Aeat303Field(79, 900, 17, _num, box: '39'),
  Aeat303Field(80, 917, 17, _signed, box: '40'),
  Aeat303Field(81, 934, 17, _signed, box: '41'),
  Aeat303Field(82, 951, 17, _signed, box: '42'),
  Aeat303Field(83, 968, 17, _signed, box: '43'),
  Aeat303Field(84, 985, 17, _signed, box: '44'),
  Aeat303Field(85, 1002, 17, _signed, box: '45'),
  Aeat303Field(86, 1019, 17, _signed, box: '46'),
  Aeat303Field(87, 1036, 521, _an),
  Aeat303Field(88, 1557, 13, _an),
  Aeat303Field(89, 1570, 12, _an, constant: '</T30301000>'),
];

/// Page 03 of the 2026 design (sheet DP30303).
const _page03 = [
  Aeat303Field(1, 1, 2, _an, constant: '<T'),
  Aeat303Field(2, 3, 3, _num, constant: '303'),
  Aeat303Field(3, 6, 5, _num, constant: '03000'),
  Aeat303Field(4, 11, 1, _an, constant: '>'),
  Aeat303Field(5, 12, 17, _signed, box: '59'),
  Aeat303Field(6, 29, 17, _signed, box: '60'),
  Aeat303Field(7, 46, 17, _signed, box: '120'),
  Aeat303Field(8, 63, 17, _signed, box: '122'),
  Aeat303Field(9, 80, 17, _signed, box: '123'),
  Aeat303Field(10, 97, 17, _signed, box: '124'),
  Aeat303Field(11, 114, 17, _signed, box: '62'),
  Aeat303Field(12, 131, 17, _signed, box: '63'),
  Aeat303Field(13, 148, 17, _signed, box: '74'),
  Aeat303Field(14, 165, 17, _signed, box: '75'),
  Aeat303Field(15, 182, 17, _signed, box: '76'),
  Aeat303Field(16, 199, 17, _signed, box: '64'),
  Aeat303Field(17, 216, 5, _num, box: '65'),
  Aeat303Field(18, 221, 17, _signed, box: '66'),
  Aeat303Field(19, 238, 17, _num, box: '77'),
  Aeat303Field(20, 255, 17, _num, box: '110'),
  Aeat303Field(21, 272, 17, _num, box: '78'),
  Aeat303Field(22, 289, 17, _num, box: '87'),
  Aeat303Field(23, 306, 17, _signed, box: '68'),
  Aeat303Field(24, 323, 17, _signed, box: '108'),
  Aeat303Field(25, 340, 17, _signed, box: '69'),
  Aeat303Field(26, 357, 17, _num, box: '70'),
  Aeat303Field(27, 374, 17, _num, box: '109'),
  Aeat303Field(28, 391, 17, _num, box: '112'),
  Aeat303Field(29, 408, 17, _signed, box: '71'),
  Aeat303Field(30, 425, 1, _an),
  Aeat303Field(31, 426, 1, _an),
  Aeat303Field(32, 427, 13, _an),
  Aeat303Field(33, 440, 1, _an),
  Aeat303Field(34, 441, 17, _num, box: '111'),
  Aeat303Field(35, 458, 1, _an),
  Aeat303Field(36, 459, 1, _an),
  Aeat303Field(37, 460, 546, _an),
  Aeat303Field(38, 1006, 12, _an, constant: '</T30303000>'),
];
