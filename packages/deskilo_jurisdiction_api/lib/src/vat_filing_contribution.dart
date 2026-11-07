// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';
import 'filing_context.dart';
import 'generated_artifact.dart';
import 'validation_result.dart';

/// What the host must have read before it asks an implementation to validate:
/// the contract names the sources, the host loads them (it keeps source
/// loading, authorization and logging).
enum FilingSource { declaration, party, facts }

/// A context that passed [VatFilingContribution.validate]. Only a
/// contribution makes one, so `build` cannot be handed an unchecked input.
class ValidatedFiling {
  ValidatedFiling(this.context);

  final FilingContext context;
}

/// The VAT filing of one jurisdiction. Pure: the same context gives the same
/// bytes; it reads no clock, network or repository.
abstract class VatFilingContribution {
  CapabilityDescriptor get descriptor;

  /// What the host loads before calling [validate].
  Set<FilingSource> get requiredSources;

  /// Whether [context] can be filed here, as stable issue codes.
  ///
  /// Returns the validated filing, or null with the issues in [result]. The
  /// pair is returned together so a caller cannot build what was refused.
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  );

  /// The file of a validated [filing].
  GeneratedArtifact build(ValidatedFiling filing);
}
