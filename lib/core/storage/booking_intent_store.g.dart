// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_intent_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookingIntentStore)
final bookingIntentStoreProvider = BookingIntentStoreProvider._();

final class BookingIntentStoreProvider
    extends
        $FunctionalProvider<
          BookingIntentStore,
          BookingIntentStore,
          BookingIntentStore
        >
    with $Provider<BookingIntentStore> {
  BookingIntentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingIntentStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingIntentStoreHash();

  @$internal
  @override
  $ProviderElement<BookingIntentStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookingIntentStore create(Ref ref) {
    return bookingIntentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookingIntentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookingIntentStore>(value),
    );
  }
}

String _$bookingIntentStoreHash() =>
    r'f6a6869ba8abad52bd3b1b2618864e19a64c2c6e';
