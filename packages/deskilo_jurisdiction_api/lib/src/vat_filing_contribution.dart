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

  /// What the host loads before calling [validate].
  Set<FilingSource> get requiredSources;

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
