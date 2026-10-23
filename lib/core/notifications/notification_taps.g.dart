// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_taps.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one inbox. main() hands the same instance to the local
/// notification service before the app starts.

@ProviderFor(notificationTaps)
final notificationTapsProvider = NotificationTapsProvider._();

/// The app's one inbox. main() hands the same instance to the local
/// notification service before the app starts.

final class NotificationTapsProvider
    extends
        $FunctionalProvider<
          NotificationTaps,
          NotificationTaps,
          NotificationTaps
        >
    with $Provider<NotificationTaps> {
  /// The app's one inbox. main() hands the same instance to the local
  /// notification service before the app starts.
  NotificationTapsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationTapsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationTapsHash();

  @$internal
  @override
  $ProviderElement<NotificationTaps> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotificationTaps create(Ref ref) {
    return notificationTaps(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationTaps value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationTaps>(value),
    );
  }
}

String _$notificationTapsHash() => r'e9ed3d1ad69b706546b948e38ccc4ad677a606f3';
