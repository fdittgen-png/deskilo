// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attention_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateSeenStore)
final updateSeenStoreProvider = UpdateSeenStoreFamily._();

final class UpdateSeenStoreProvider
    extends
        $FunctionalProvider<UpdateSeenStore, UpdateSeenStore, UpdateSeenStore>
    with $Provider<UpdateSeenStore> {
  UpdateSeenStoreProvider._({
    required UpdateSeenStoreFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'updateSeenStoreProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$updateSeenStoreHash();

  @override
  String toString() {
    return r'updateSeenStoreProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<UpdateSeenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateSeenStore create(Ref ref) {
    final argument = this.argument as String;
    return updateSeenStore(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateSeenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateSeenStore>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UpdateSeenStoreProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$updateSeenStoreHash() => r'a051ece75fba0d33140fb8e91c510a13052e11e9';

final class UpdateSeenStoreFamily extends $Family
    with $FunctionalFamilyOverride<UpdateSeenStore, String> {
  UpdateSeenStoreFamily._()
    : super(
        retry: null,
        name: r'updateSeenStoreProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  UpdateSeenStoreProvider call(String key) =>
      UpdateSeenStoreProvider._(argument: key, from: this);

  @override
  String toString() => r'updateSeenStoreProvider';
}

/// A device acknowledgement belongs to one person, server and workspace.

@ProviderFor(attentionScope)
final attentionScopeProvider = AttentionScopeProvider._();

/// A device acknowledgement belongs to one person, server and workspace.

final class AttentionScopeProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// A device acknowledgement belongs to one person, server and workspace.
  AttentionScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attentionScopeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attentionScopeHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return attentionScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$attentionScopeHash() => r'70cbfc0427df97e08d205537c9fe6ea0b7b4ae50';

/// Badges clear immediately; the currently visible feed retains its new rows.

@ProviderFor(UpdatesSeen)
final updatesSeenProvider = UpdatesSeenFamily._();

/// Badges clear immediately; the currently visible feed retains its new rows.
final class UpdatesSeenProvider
    extends $AsyncNotifierProvider<UpdatesSeen, UpdateReadState> {
  /// Badges clear immediately; the currently visible feed retains its new rows.
  UpdatesSeenProvider._({
    required UpdatesSeenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'updatesSeenProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$updatesSeenHash();

  @override
  String toString() {
    return r'updatesSeenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UpdatesSeen create() => UpdatesSeen();

  @override
  bool operator ==(Object other) {
    return other is UpdatesSeenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$updatesSeenHash() => r'75a359c9bbf8c060b482ad16a3ac0b7b65cd16d1';

/// Badges clear immediately; the currently visible feed retains its new rows.

final class UpdatesSeenFamily extends $Family
    with
        $ClassFamilyOverride<
          UpdatesSeen,
          AsyncValue<UpdateReadState>,
          UpdateReadState,
          FutureOr<UpdateReadState>,
          String
        > {
  UpdatesSeenFamily._()
    : super(
        retry: null,
        name: r'updatesSeenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Badges clear immediately; the currently visible feed retains its new rows.

  UpdatesSeenProvider call(String scope) =>
      UpdatesSeenProvider._(argument: scope, from: this);

  @override
  String toString() => r'updatesSeenProvider';
}

/// Badges clear immediately; the currently visible feed retains its new rows.

abstract class _$UpdatesSeen extends $AsyncNotifier<UpdateReadState> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  FutureOr<UpdateReadState> build(String scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UpdateReadState>, UpdateReadState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UpdateReadState>, UpdateReadState>,
              AsyncValue<UpdateReadState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The count uses the same authorized feed and pending-decision list as Alerts.
/// An unread pending event counts once, and direct messages stay in Messages.

@ProviderFor(workspaceAttention)
final workspaceAttentionProvider = WorkspaceAttentionProvider._();

/// The count uses the same authorized feed and pending-decision list as Alerts.
/// An unread pending event counts once, and direct messages stay in Messages.

final class WorkspaceAttentionProvider
    extends
        $FunctionalProvider<AttentionCounts, AttentionCounts, AttentionCounts>
    with $Provider<AttentionCounts> {
  /// The count uses the same authorized feed and pending-decision list as Alerts.
  /// An unread pending event counts once, and direct messages stay in Messages.
  WorkspaceAttentionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceAttentionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceAttentionHash();

  @$internal
  @override
  $ProviderElement<AttentionCounts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttentionCounts create(Ref ref) {
    return workspaceAttention(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttentionCounts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttentionCounts>(value),
    );
  }
}

String _$workspaceAttentionHash() =>
    r'f2e38fd99c155294217db4dcfd04006a1503f802';
