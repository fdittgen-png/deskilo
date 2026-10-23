// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_tap_routing.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Takes every tap, from the moment the app is composed (a launch tap
/// waited in the inbox until now).

@ProviderFor(notificationTapRouting)
final notificationTapRoutingProvider = NotificationTapRoutingProvider._();

/// Takes every tap, from the moment the app is composed (a launch tap
/// waited in the inbox until now).

final class NotificationTapRoutingProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Takes every tap, from the moment the app is composed (a launch tap
  /// waited in the inbox until now).
  NotificationTapRoutingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationTapRoutingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationTapRoutingHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return notificationTapRouting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$notificationTapRoutingHash() =>
    r'071eab46747f950492a44dcda278228a8d4a57bf';
