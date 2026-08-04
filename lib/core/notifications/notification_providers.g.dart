// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in main() with the initialized [LocalNotificationService]
/// and in tests with a fake — there is no safe synchronous default.

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

/// Overridden in main() with the initialized [LocalNotificationService]
/// and in tests with a fake — there is no safe synchronous default.

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  /// Overridden in main() with the initialized [LocalNotificationService]
  /// and in tests with a fake — there is no safe synchronous default.
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'2c35d60b259955cbe34e08eacf3bba3cd76a6d2e';

/// System-level notification permission truth (#436): false = Android
/// suppresses every notification of this app; Settings names the fix.

@ProviderFor(systemNotificationsEnabled)
final systemNotificationsEnabledProvider =
    SystemNotificationsEnabledProvider._();

/// System-level notification permission truth (#436): false = Android
/// suppresses every notification of this app; Settings names the fix.

final class SystemNotificationsEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool?>, bool?, FutureOr<bool?>>
    with $FutureModifier<bool?>, $FutureProvider<bool?> {
  /// System-level notification permission truth (#436): false = Android
  /// suppresses every notification of this app; Settings names the fix.
  SystemNotificationsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemNotificationsEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemNotificationsEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool?> create(Ref ref) {
    return systemNotificationsEnabled(ref);
  }
}

String _$systemNotificationsEnabledHash() =>
    r'0b196171f85acb1617b88cdf8d59ed52dd8a216b';
