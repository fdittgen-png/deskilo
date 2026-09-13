// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_bar_visibility.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(shellBarHiddenStore)
final shellBarHiddenStoreProvider = ShellBarHiddenStoreProvider._();

final class ShellBarHiddenStoreProvider
    extends $FunctionalProvider<ShellFlagStore, ShellFlagStore, ShellFlagStore>
    with $Provider<ShellFlagStore> {
  ShellBarHiddenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellBarHiddenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellBarHiddenStoreHash();

  @$internal
  @override
  $ProviderElement<ShellFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellFlagStore create(Ref ref) {
    return shellBarHiddenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellFlagStore>(value),
    );
  }
}

String _$shellBarHiddenStoreHash() =>
    r'1071436bcb1ea3567965962ed7174206ddb12fcf';

@ProviderFor(shellSwipeCoachStore)
final shellSwipeCoachStoreProvider = ShellSwipeCoachStoreProvider._();

final class ShellSwipeCoachStoreProvider
    extends $FunctionalProvider<ShellFlagStore, ShellFlagStore, ShellFlagStore>
    with $Provider<ShellFlagStore> {
  ShellSwipeCoachStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSwipeCoachStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSwipeCoachStoreHash();

  @$internal
  @override
  $ProviderElement<ShellFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellFlagStore create(Ref ref) {
    return shellSwipeCoachStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellFlagStore>(value),
    );
  }
}

String _$shellSwipeCoachStoreHash() =>
    r'cbdf62c0f9172a79b02b92a082d2cb5e052661eb';

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.

@ProviderFor(ShellBarHidden)
final shellBarHiddenProvider = ShellBarHiddenProvider._();

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.
final class ShellBarHiddenProvider
    extends $AsyncNotifierProvider<ShellBarHidden, bool> {
  /// The swiped-away state. Loading reads as SHOWN: the safe state, since
  /// it is the one that carries its own way out.
  ShellBarHiddenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellBarHiddenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellBarHiddenHash();

  @$internal
  @override
  ShellBarHidden create() => ShellBarHidden();
}

String _$shellBarHiddenHash() => r'1b9fea1a78be6ff0be35a156848a245251381bc1';

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.

abstract class _$ShellBarHidden extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.

@ProviderFor(ShellSwipeCoachSeen)
final shellSwipeCoachSeenProvider = ShellSwipeCoachSeenProvider._();

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.
final class ShellSwipeCoachSeenProvider
    extends $AsyncNotifierProvider<ShellSwipeCoachSeen, bool> {
  /// Whether the swipe coach mark has been shown (#1173).
  ///
  /// Once ever, like the tip carousels of #610: a gesture needs
  /// introducing exactly one time, and a hint that returns is an
  /// annoyance rather than help. Loading reads as SEEN, so a member can
  /// never be shown a hint that cannot be remembered as dismissed.
  ShellSwipeCoachSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSwipeCoachSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSwipeCoachSeenHash();

  @$internal
  @override
  ShellSwipeCoachSeen create() => ShellSwipeCoachSeen();
}

String _$shellSwipeCoachSeenHash() =>
    r'bdf9d0d487fbd4c3c5b9dcb5be97b1072cfb9ca7';

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.

abstract class _$ShellSwipeCoachSeen extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
