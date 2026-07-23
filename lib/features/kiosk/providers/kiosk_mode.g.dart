// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kiosk_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Deliberately IN-MEMORY: the decision dies with the process, so once
/// kiosk mode is accepted the only way out is restarting the pad — and
/// every restart asks again, which is also how a rejected pad can be
/// turned back into a kiosk.

@ProviderFor(KioskMode)
final kioskModeProvider = KioskModeProvider._();

/// Deliberately IN-MEMORY: the decision dies with the process, so once
/// kiosk mode is accepted the only way out is restarting the pad — and
/// every restart asks again, which is also how a rejected pad can be
/// turned back into a kiosk.
final class KioskModeProvider
    extends $NotifierProvider<KioskMode, KioskModeDecision> {
  /// Deliberately IN-MEMORY: the decision dies with the process, so once
  /// kiosk mode is accepted the only way out is restarting the pad — and
  /// every restart asks again, which is also how a rejected pad can be
  /// turned back into a kiosk.
  KioskModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kioskModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kioskModeHash();

  @$internal
  @override
  KioskMode create() => KioskMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KioskModeDecision value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KioskModeDecision>(value),
    );
  }
}

String _$kioskModeHash() => r'074905d704abb0de88c2989e59b33d8dd1bc3c47';

/// Deliberately IN-MEMORY: the decision dies with the process, so once
/// kiosk mode is accepted the only way out is restarting the pad — and
/// every restart asks again, which is also how a rejected pad can be
/// turned back into a kiosk.

abstract class _$KioskMode extends $Notifier<KioskModeDecision> {
  KioskModeDecision build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<KioskModeDecision, KioskModeDecision>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<KioskModeDecision, KioskModeDecision>,
              KioskModeDecision,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
