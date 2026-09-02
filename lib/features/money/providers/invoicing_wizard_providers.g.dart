// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoicing_wizard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #827 — what every active member would be invoiced for [period], ALL
/// kinds (the wizard narrows to its run's kind). A member whose preview
/// fails is left out and traced, never a blocked run.

@ProviderFor(wizardPreviews)
final wizardPreviewsProvider = WizardPreviewsFamily._();

/// #827 — what every active member would be invoiced for [period], ALL
/// kinds (the wizard narrows to its run's kind). A member whose preview
/// fails is left out and traced, never a blocked run.

final class WizardPreviewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ({List<InvoiceLine> lines, int totalCents})>>,
          Map<String, ({List<InvoiceLine> lines, int totalCents})>,
          FutureOr<Map<String, ({List<InvoiceLine> lines, int totalCents})>>
        >
    with
        $FutureModifier<
          Map<String, ({List<InvoiceLine> lines, int totalCents})>
        >,
        $FutureProvider<
          Map<String, ({List<InvoiceLine> lines, int totalCents})>
        > {
  /// #827 — what every active member would be invoiced for [period], ALL
  /// kinds (the wizard narrows to its run's kind). A member whose preview
  /// fails is left out and traced, never a blocked run.
  WizardPreviewsProvider._({
    required WizardPreviewsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'wizardPreviewsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wizardPreviewsHash();

  @override
  String toString() {
    return r'wizardPreviewsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<
    Map<String, ({List<InvoiceLine> lines, int totalCents})>
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, ({List<InvoiceLine> lines, int totalCents})>> create(
    Ref ref,
  ) {
    final argument = this.argument as String;
    return wizardPreviews(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WizardPreviewsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wizardPreviewsHash() => r'99a0de28d72d7ef7809594d83a13b011dea6fddb';

/// #827 — what every active member would be invoiced for [period], ALL
/// kinds (the wizard narrows to its run's kind). A member whose preview
/// fails is left out and traced, never a blocked run.

final class WizardPreviewsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, ({List<InvoiceLine> lines, int totalCents})>>,
          String
        > {
  WizardPreviewsFamily._()
    : super(
        retry: null,
        name: r'wizardPreviewsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #827 — what every active member would be invoiced for [period], ALL
  /// kinds (the wizard narrows to its run's kind). A member whose preview
  /// fails is left out and traced, never a blocked run.

  WizardPreviewsProvider call(String period) =>
      WizardPreviewsProvider._(argument: period, from: this);

  @override
  String toString() => r'wizardPreviewsProvider';
}

/// #827 — the wizard's session: the run, the step, the tally. Kept
/// alive so a sheet opened from a step (a match, a settlement) returns
/// to the same place with the same numbers.

@ProviderFor(InvoicingWizardController)
final invoicingWizardControllerProvider = InvoicingWizardControllerProvider._();

/// #827 — the wizard's session: the run, the step, the tally. Kept
/// alive so a sheet opened from a step (a match, a settlement) returns
/// to the same place with the same numbers.
final class InvoicingWizardControllerProvider
    extends $NotifierProvider<InvoicingWizardController, WizardState> {
  /// #827 — the wizard's session: the run, the step, the tally. Kept
  /// alive so a sheet opened from a step (a match, a settlement) returns
  /// to the same place with the same numbers.
  InvoicingWizardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoicingWizardControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoicingWizardControllerHash();

  @$internal
  @override
  InvoicingWizardController create() => InvoicingWizardController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WizardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WizardState>(value),
    );
  }
}

String _$invoicingWizardControllerHash() =>
    r'287d51a3ceb8bfbce631d8ab3d9487e75e40160d';

/// #827 — the wizard's session: the run, the step, the tally. Kept
/// alive so a sheet opened from a step (a match, a settlement) returns
/// to the same place with the same numbers.

abstract class _$InvoicingWizardController extends $Notifier<WizardState> {
  WizardState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<WizardState, WizardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WizardState, WizardState>,
              WizardState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
