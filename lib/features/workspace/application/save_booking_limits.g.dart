// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_booking_limits.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The booking limits' write.

@ProviderFor(saveBookingLimits)
final saveBookingLimitsProvider = SaveBookingLimitsProvider._();

/// The booking limits' write.

final class SaveBookingLimitsProvider
    extends
        $FunctionalProvider<
          SaveBookingLimits,
          SaveBookingLimits,
          SaveBookingLimits
        >
    with $Provider<SaveBookingLimits> {
  /// The booking limits' write.
  SaveBookingLimitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveBookingLimitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveBookingLimitsHash();

  @$internal
  @override
  $ProviderElement<SaveBookingLimits> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveBookingLimits create(Ref ref) {
    return saveBookingLimits(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveBookingLimits value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveBookingLimits>(value),
    );
  }
}

String _$saveBookingLimitsHash() => r'eaf08312e1a4e1de34a22d115feb02c8a81abc55';
