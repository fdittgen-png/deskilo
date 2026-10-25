// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what each saved VAT declaration's card says: its stage, the
// rate label of each line, whether corrections or deductible VAT appear,
// the balance left to pay or to claim back, and the filing reference.
// The card maps over these values; it decides nothing.
import '../domain/vat_declaration.dart';

/// Where a declaration stands.
enum VatDeclarationStage { draft, prepared, filed }

class VatDeclarationRow {
  const VatDeclarationRow(this.declaration);

  final VatDeclaration declaration;

  VatDeclarationStage get stage => declaration.isFiled
      ? VatDeclarationStage.filed
      : declaration.isPrepared
      ? VatDeclarationStage.prepared
      : VatDeclarationStage.draft;

  /// Only a prepared declaration can be marked as filed.
  bool get canMarkFiled => declaration.isPrepared;

  /// A filed return was corrected in this period: the card says how.
  bool get hasCorrections => declaration.lines.any((l) => l.isCorrection);

  /// #2357 — with deductible VAT, the balance is said.
  bool get hasInputVat => declaration.lines.any((l) => l.isInput);

  /// True when VAT is left to pay, false when it is claimed back.
  bool get payable => declaration.totalVatCents >= 0;

  int get balanceCents => declaration.totalVatCents.abs();

  /// A line names what it is beside its rate (deductible VAT, a
  /// correction); the period's own sales do not.
  static bool hasNote(VatDeclarationLine line) =>
      line.isCorrection || line.isInput;

  /// `20 %`, `5.5 %`: a whole rate without decimals.
  static String percentLabel(double percent) =>
      percent == percent.roundToDouble()
      ? '${percent.toStringAsFixed(0)} %'
      : '$percent %';

  /// Number, channel and receipt of a filed declaration, empty parts
  /// left out; null until it is filed.
  String? get filedLine => !declaration.isFiled
      ? null
      : '${declaration.number.isEmpty ? '' : '${declaration.number} · '}'
            '${declaration.submittedChannel}'
            '${declaration.submittedReceipt.isEmpty ? '' : ' · ${declaration.submittedReceipt}'}';
}

abstract final class VatDeclarationRows {
  static List<VatDeclarationRow> of(List<VatDeclaration> declarations) => [
    for (final d in declarations) VatDeclarationRow(d),
  ];
}
