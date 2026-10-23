// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_draft_autosave.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The draft of one setup [step] of one workspace.

@ProviderFor(SetupDraftAutosave)
final setupDraftAutosaveProvider = SetupDraftAutosaveFamily._();

/// The draft of one setup [step] of one workspace.
final class SetupDraftAutosaveProvider
    extends $NotifierProvider<SetupDraftAutosave, SetupDraftState> {
  /// The draft of one setup [step] of one workspace.
  SetupDraftAutosaveProvider._({
    required SetupDraftAutosaveFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'setupDraftAutosaveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$setupDraftAutosaveHash();

  @override
  String toString() {
    return r'setupDraftAutosaveProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SetupDraftAutosave create() => SetupDraftAutosave();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetupDraftState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetupDraftState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SetupDraftAutosaveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$setupDraftAutosaveHash() =>
    r'88e89d3cb8f7a0a1e9326df179d9325414d0638b';

/// The draft of one setup [step] of one workspace.

final class SetupDraftAutosaveFamily extends $Family
    with
        $ClassFamilyOverride<
          SetupDraftAutosave,
          SetupDraftState,
          SetupDraftState,
          SetupDraftState,
          (String, String)
        > {
  SetupDraftAutosaveFamily._()
    : super(
        retry: null,
        name: r'setupDraftAutosaveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The draft of one setup [step] of one workspace.

  SetupDraftAutosaveProvider call(String workspaceId, String step) =>
      SetupDraftAutosaveProvider._(argument: (workspaceId, step), from: this);

  @override
  String toString() => r'setupDraftAutosaveProvider';
}

/// The draft of one setup [step] of one workspace.

abstract class _$SetupDraftAutosave extends $Notifier<SetupDraftState> {
  late final _$args = ref.$arg as (String, String);
  String get workspaceId => _$args.$1;
  String get step => _$args.$2;

  SetupDraftState build(String workspaceId, String step);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SetupDraftState, SetupDraftState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetupDraftState, SetupDraftState>,
              SetupDraftState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
