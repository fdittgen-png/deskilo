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
