// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';
import 'filing_context.dart';
import 'generated_artifact.dart';
import 'validation_result.dart';

/// What the host must have read before it asks an implementation to validate:
/// the contract names the sources, the host loads them (it keeps source
/// loading, authorization and logging).
enum FilingSource { declaration, party, facts }

/// A context a contribution validated. It is public so an implementation can
/// make one, but it proves nothing by itself: `build` must validate again and
/// refuse a filing its own `validate` would not issue (see
/// [VatFilingContribution.build]).
class ValidatedFiling {
  ValidatedFiling(this.context);

  final FilingContext context;
}

/// The VAT filing of one jurisdiction. Pure: the same context gives the same
/// bytes; it reads no clock, network or repository.
abstract class VatFilingContribution {
  const VatFilingContribution();

  CapabilityDescriptor get descriptor;

  /// The forms filed beside the main return that the host fills boxes for
  /// (the Quebec `FPZ-500` beside the federal return), by the form's own name;
  /// they arrive in `FilingContext.extraBoxes`. Additive: none by default, the
  /// contract stays at the same version.
  Set<String> get extraForms => const {};

  /// The registers of issued invoices the country's law asks for beside the
  /// return, by the id the host's register kind carries (Spain's `esLibro`,
  /// `esSii`, `es347`); the host offers exactly these. Additive: none by
  /// default, the contract stays at the same version.
  Set<String> get registers => const {};

  /// Whether the country's tax authority takes the return by direct
  /// submission from the application (the UK's Making Tax Digital); the host
  /// offers that door for exactly the countries that say so. Additive: the
  /// contract stays at the same version.
  bool get directSubmission => false;

  /// The fields of the legal identity form only this country's law asks of a
  /// VAT-registered business, by id (`ukLandTax`, `swissLetting`,
  /// `canadaTax`); the host maps each to its widget. None by default.
  /// Additive: the contract stays at the same version.
  Set<String> get legalIdentityFields => const {};

  /// Whether a VAT-registered business that never chose when its VAT falls
  /// due is taxed on receipts by default (France, for services); the host
  /// tells such a space once. Additive: the contract stays at the same
  /// version.
  bool get taxPointOnReceiptsByDefault => false;

  /// Whether the country asks the electronic reporting of the sales a VAT
  /// return does not carry (France's e-reporting flows); the host offers that
  /// export for exactly the countries that say so. Additive: the contract stays
  /// at the same version.
  bool get eReporting => false;

  /// What the host loads before calling [validate].
  Set<FilingSource> get requiredSources;

  /// The id of the label of this filing's button on the declarations screen
  /// (`elster`, `ediTva`, `mtdCsv`, `mwstXml`, `gstQstCsv`, `aeat303`,
  /// `lipeXml`); the host maps it to its words. '' says the filing has none.
  /// Additive: the contract stays at the same version.
  String get fileButtonId => '';

  /// What the filing still asks the person before it is written, by id
  /// (`taxNumber`: the Steuernummer; `spanishFacts`; `italianDeclarant`); the
  /// host maps each to its dialog. None by default. Additive.
  Set<String> get factsAsked => const {};

  /// Whether [context] can be filed here, as stable issue codes.
  ///
  /// Returns the validated filing, or null with the issues in [result]. The
  /// pair is returned together so a caller cannot build what was refused.
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  );

  /// The file of a validated [filing]. An implementation validates [filing]
  /// again and throws a [StateError] when its own [validate] would refuse it
  /// (a foreign or hand-made filing): `build` never skips the checks.
  GeneratedArtifact build(ValidatedFiling filing);
}
