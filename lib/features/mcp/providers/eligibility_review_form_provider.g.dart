// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eligibility_review_form_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EligibilityReviewForm)
final eligibilityReviewFormProvider = EligibilityReviewFormProvider._();

final class EligibilityReviewFormProvider
    extends
        $NotifierProvider<EligibilityReviewForm, EligibilityReviewFormState> {
  EligibilityReviewFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eligibilityReviewFormProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eligibilityReviewFormHash();

  @$internal
  @override
  EligibilityReviewForm create() => EligibilityReviewForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EligibilityReviewFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EligibilityReviewFormState>(value),
    );
  }
}

String _$eligibilityReviewFormHash() =>
    r'e7c21318ebd9c33b8465b0b2d4e770a7f4343fce';

abstract class _$EligibilityReviewForm
    extends $Notifier<EligibilityReviewFormState> {
  EligibilityReviewFormState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<EligibilityReviewFormState, EligibilityReviewFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                EligibilityReviewFormState,
                EligibilityReviewFormState
              >,
              EligibilityReviewFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
