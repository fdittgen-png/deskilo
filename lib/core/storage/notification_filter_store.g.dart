// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_filter_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationFilterStore)
final notificationFilterStoreProvider = NotificationFilterStoreProvider._();

final class NotificationFilterStoreProvider
    extends
        $FunctionalProvider<
          NotificationFilterStore,
          NotificationFilterStore,
          NotificationFilterStore
        >
    with $Provider<NotificationFilterStore> {
  NotificationFilterStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationFilterStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationFilterStoreHash();

  @$internal
  @override
  $ProviderElement<NotificationFilterStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationFilterStore create(Ref ref) {
    return notificationFilterStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationFilterStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationFilterStore>(value),
    );
  }
}

String _$notificationFilterStoreHash() =>
    r'8848e61d916882346a3174fd9b10d2b08401281a';
