// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2576 (C2) — the words the valuations share: the basis of a batch, where it
/// stands, whether a row balances, and the figures of one row as a file states
/// them. A blank figure is UNKNOWN (null) and stays unknown.
library;

enum ValuationBasis {
  book('book'),
  tax('tax');

  const ValuationBasis(this.wire);

  final String wire;

  static ValuationBasis? of(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

enum ValuationStatus {
  staged('staged'),
  confirmed('confirmed'),
  superseded('superseded');

  const ValuationStatus(this.wire);

  final String wire;

  static ValuationStatus of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => staged);
}

/// Whether a row's figures balance: opening plus additions less disposals,
/// depreciation and impairment is the closing value.
enum ValuationBridge { ok, mismatch, unknown }

/// One asset's figures as the file states them; null is unknown.
class ValuationRowDraft {
  const ValuationRowDraft({
    required this.assetNumber,
    this.externalReference = '',
    this.openingMinor,
    this.additionsMinor,
    this.disposalsMinor,
    this.depreciationMinor,
    this.impairmentMinor,
    this.closingMinor,
  });

  final int assetNumber;
  final String externalReference;
  final int? openingMinor;
  final int? additionsMinor;
  final int? disposalsMinor;
  final int? depreciationMinor;
  final int? impairmentMinor;
  final int? closingMinor;

  /// The bridge the same way the server computes it.
  ValuationBridge get bridge {
    final f = [
      openingMinor,
      additionsMinor,
      disposalsMinor,
      depreciationMinor,
      impairmentMinor,
      closingMinor,
    ];
    if (f.any((x) => x == null)) return ValuationBridge.unknown;
    return openingMinor! +
                additionsMinor! -
                disposalsMinor! -
                depreciationMinor! -
                impairmentMinor! ==
            closingMinor!
        ? ValuationBridge.ok
        : ValuationBridge.mismatch;
  }

  Map<String, Object?> toJson() => {
    'asset_number': assetNumber,
    'external_reference': externalReference,
    'opening_minor': openingMinor,
    'additions_minor': additionsMinor,
    'disposals_minor': disposalsMinor,
    'depreciation_minor': depreciationMinor,
    'impairment_minor': impairmentMinor,
    'closing_minor': closingMinor,
  };
}
