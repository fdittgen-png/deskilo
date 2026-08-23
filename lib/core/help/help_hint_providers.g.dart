// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_hint_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The set of dismissed hint ids (#606), loaded from disk once and kept
/// in sync eagerly on every change — the notification-filter idiom.
/// Unknown ids in the stored set are tolerated by design: a hint that no
/// longer exists simply never asks to be shown.

@ProviderFor(DismissedHelpHints)
final dismissedHelpHintsProvider = DismissedHelpHintsProvider._();

/// The set of dismissed hint ids (#606), loaded from disk once and kept
/// in sync eagerly on every change — the notification-filter idiom.
/// Unknown ids in the stored set are tolerated by design: a hint that no
/// longer exists simply never asks to be shown.
final class DismissedHelpHintsProvider
    extends $AsyncNotifierProvider<DismissedHelpHints, Set<String>> {
  /// The set of dismissed hint ids (#606), loaded from disk once and kept
  /// in sync eagerly on every change — the notification-filter idiom.
  /// Unknown ids in the stored set are tolerated by design: a hint that no
  /// longer exists simply never asks to be shown.
  DismissedHelpHintsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dismissedHelpHintsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dismissedHelpHintsHash();

  @$internal
  @override
  DismissedHelpHints create() => DismissedHelpHints();
}

String _$dismissedHelpHintsHash() =>
    r'f0fbe75c24ade2a5f9c48c88356d1682788db7a0';

/// The set of dismissed hint ids (#606), loaded from disk once and kept
/// in sync eagerly on every change — the notification-filter idiom.
/// Unknown ids in the stored set are tolerated by design: a hint that no
/// longer exists simply never asks to be shown.

abstract class _$DismissedHelpHints extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The last-shown tip index per surface (#610) — the memory behind the
/// carousel's rotation: a fresh visit opens on the tip AFTER this one.
/// Stored indices from an older tip list are tolerated: the widget takes
/// them modulo the current tip count.

@ProviderFor(HelpHintPositions)
final helpHintPositionsProvider = HelpHintPositionsProvider._();

/// The last-shown tip index per surface (#610) — the memory behind the
/// carousel's rotation: a fresh visit opens on the tip AFTER this one.
/// Stored indices from an older tip list are tolerated: the widget takes
/// them modulo the current tip count.
final class HelpHintPositionsProvider
    extends $AsyncNotifierProvider<HelpHintPositions, Map<String, int>> {
  /// The last-shown tip index per surface (#610) — the memory behind the
  /// carousel's rotation: a fresh visit opens on the tip AFTER this one.
  /// Stored indices from an older tip list are tolerated: the widget takes
  /// them modulo the current tip count.
  HelpHintPositionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpHintPositionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpHintPositionsHash();

  @$internal
  @override
  HelpHintPositions create() => HelpHintPositions();
}

String _$helpHintPositionsHash() => r'26d412e376dd949eab017c3016b1eb2f3f9f1a6f';

/// The last-shown tip index per surface (#610) — the memory behind the
/// carousel's rotation: a fresh visit opens on the tip AFTER this one.
/// Stored indices from an older tip list are tolerated: the widget takes
/// them modulo the current tip count.

abstract class _$HelpHintPositions extends $AsyncNotifier<Map<String, int>> {
  FutureOr<Map<String, int>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, int>>, Map<String, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, int>>, Map<String, int>>,
              AsyncValue<Map<String, int>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
