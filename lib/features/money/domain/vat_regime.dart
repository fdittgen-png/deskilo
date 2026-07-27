// SPDX-License-Identifier: 0BSD

/// How the workspace stands towards VAT — the one fact EN 16931 cannot
/// guess and cannot omit (BT-151, the invoice's tax category).
///
/// The norm's fatal rules differ per category, which is why this is a
/// declaration and not a default:
///  * [notSubject] → category `O`. BR-O-02 FORBIDS a seller VAT or tax
///    registration identifier; BR-CO-26 still needs an identifier, so the
///    legal registration number (BT-30) carries it.
///  * [exempt] → category `E`. BR-E-02 REQUIRES a seller VAT (or tax
///    registration) identifier and BR-E-10 an exemption reason.
///  * [vatRegistered] → the app does not track VAT rates per position, so
///    no truthful breakdown can be produced; the export refuses instead of
///    declaring a zero tax that the seller does owe.
enum VatRegime {
  /// Services outside the scope of VAT.
  notSubject,

  /// Within scope but exempt — a national small-business scheme
  /// (franchise en base de TVA, Kleinunternehmerregelung, régimen de
  /// franquicia…).
  exempt,

  /// A VAT-charging business.
  vatRegistered,
}

const _wire = {
  VatRegime.notSubject: 'not_subject',
  VatRegime.exempt: 'exempt',
  VatRegime.vatRegistered: 'vat_registered',
};

String vatRegimeWire(VatRegime regime) => _wire[regime]!;

VatRegime vatRegimeFromWire(String? wire) => switch (wire) {
      'exempt' => VatRegime.exempt,
      'vat_registered' => VatRegime.vatRegistered,
      _ => VatRegime.notSubject,
    };

extension VatRegimeRules on VatRegime {
  /// The UNCL5305 tax category code the positions carry (BT-151).
  String get taxCategoryCode => switch (this) {
        VatRegime.notSubject => 'O',
        VatRegime.exempt => 'E',
        // Never reaches the XML — the export refuses first.
        VatRegime.vatRegistered => 'S',
      };

  /// The VATEX exemption-reason code, where the code lists have one.
  /// Category O has exactly one (`VATEX-EU-O`, mandated by BR-O-10);
  /// category E has national codes — France's franchise en base is the
  /// only one this app can name with certainty, everything else falls
  /// back to the owner's free-text reason (BR-E-10 accepts either).
  String exemptionReasonCode(String countryCode) => switch (this) {
        VatRegime.notSubject => 'VATEX-EU-O',
        VatRegime.exempt =>
          countryCode.toUpperCase() == 'FR' ? 'VATEX-FR-FRANCHISE' : '',
        VatRegime.vatRegistered => '',
      };

  /// Whether a seller VAT / tax registration identifier is REQUIRED
  /// (category E) — or forbidden (category O, BR-O-02).
  bool get requiresVatId => this == VatRegime.exempt;

  /// Category O must not carry one.
  bool get forbidsVatId => this == VatRegime.notSubject;
}
