// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The owner of the current session. It lives ABOVE the Demo scope: a
/// provider inside the scope would be disposed by the very reset it was
/// asked to perform.

@ProviderFor(DemoSessionController)
final demoSessionControllerProvider = DemoSessionControllerProvider._();

/// The owner of the current session. It lives ABOVE the Demo scope: a
/// provider inside the scope would be disposed by the very reset it was
/// asked to perform.
final class DemoSessionControllerProvider
    extends $NotifierProvider<DemoSessionController, DemoSession> {
  /// The owner of the current session. It lives ABOVE the Demo scope: a
  /// provider inside the scope would be disposed by the very reset it was
  /// asked to perform.
  DemoSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demoSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoSessionControllerHash();

  @$internal
  @override
  DemoSessionController create() => DemoSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DemoSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DemoSession>(value),
    );
  }
}

String _$demoSessionControllerHash() =>
    r'40e603012358843a0890ed703d4dcb88e5853668';

/// The owner of the current session. It lives ABOVE the Demo scope: a
/// provider inside the scope would be disposed by the very reset it was
/// asked to perform.

abstract class _$DemoSessionController extends $Notifier<DemoSession> {
  DemoSession build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DemoSession, DemoSession>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DemoSession, DemoSession>,
              DemoSession,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
