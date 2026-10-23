// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_payment_instructions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The payment instructions' one write.

@ProviderFor(savePaymentInstructions)
final savePaymentInstructionsProvider = SavePaymentInstructionsProvider._();

/// The payment instructions' one write.

final class SavePaymentInstructionsProvider
    extends
        $FunctionalProvider<
          SavePaymentInstructions,
          SavePaymentInstructions,
          SavePaymentInstructions
        >
    with $Provider<SavePaymentInstructions> {
  /// The payment instructions' one write.
  SavePaymentInstructionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savePaymentInstructionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savePaymentInstructionsHash();

  @$internal
  @override
  $ProviderElement<SavePaymentInstructions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavePaymentInstructions create(Ref ref) {
    return savePaymentInstructions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavePaymentInstructions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavePaymentInstructions>(value),
    );
  }
}

String _$savePaymentInstructionsHash() =>
    r'dedffca303ae1802177aa106f8a4ed004c340542';
