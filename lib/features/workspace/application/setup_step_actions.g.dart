// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_step_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2869 (0545) — the guide's Later, Mark as done and Undo.

@ProviderFor(setupStepActions)
final setupStepActionsProvider = SetupStepActionsProvider._();

/// #2869 (0545) — the guide's Later, Mark as done and Undo.

final class SetupStepActionsProvider
    extends
        $FunctionalProvider<
          SetupStepActions,
          SetupStepActions,
          SetupStepActions
        >
    with $Provider<SetupStepActions> {
  /// #2869 (0545) — the guide's Later, Mark as done and Undo.
  SetupStepActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupStepActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupStepActionsHash();

  @$internal
  @override
  $ProviderElement<SetupStepActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SetupStepActions create(Ref ref) {
    return setupStepActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetupStepActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetupStepActions>(value),
    );
  }
}

String _$setupStepActionsHash() => r'8cd419f9b26803a69b0463a53d4b38dfd14c4482';
