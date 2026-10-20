// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2484 -- the settings registry: read and written.
///
/// #2564 O2 -- NOT on the selected workspace's client: the workspace context
/// captures these settings (currentSettingsCapture), and the selected client
/// is derived from that context, so watching it here closes a provider cycle
/// that rebuilds without end (one tester grew to 25 GB). Settings stay on the
/// pre-context client until the context's host binding no longer waits for
/// its settings capture.

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

/// #2484 -- the settings registry: read and written.
///
/// #2564 O2 -- NOT on the selected workspace's client: the workspace context
/// captures these settings (currentSettingsCapture), and the selected client
/// is derived from that context, so watching it here closes a provider cycle
/// that rebuilds without end (one tester grew to 25 GB). Settings stay on the
/// pre-context client until the context's host binding no longer waits for
/// its settings capture.

final class SettingsRepositoryProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
  /// #2484 -- the settings registry: read and written.
  ///
  /// #2564 O2 -- NOT on the selected workspace's client: the workspace context
  /// captures these settings (currentSettingsCapture), and the selected client
  /// is derived from that context, so watching it here closes a provider cycle
  /// that rebuilds without end (one tester grew to 25 GB). Settings stay on the
  /// pre-context client until the context's host binding no longer waits for
  /// its settings capture.
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsStore create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsStore>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'398ffcf9e82a21970855c9d19fda634328850bc2';

/// The registry, falling back to the definitions bundled with the app
/// (defaults only) when the installation cannot answer.

@ProviderFor(settingsSource)
final settingsSourceProvider = SettingsSourceProvider._();

/// The registry, falling back to the definitions bundled with the app
/// (defaults only) when the installation cannot answer.

final class SettingsSourceProvider
    extends $FunctionalProvider<SettingsSource, SettingsSource, SettingsSource>
    with $Provider<SettingsSource> {
  /// The registry, falling back to the definitions bundled with the app
  /// (defaults only) when the installation cannot answer.
  SettingsSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsSourceHash();

  @$internal
  @override
  $ProviderElement<SettingsSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsSource create(Ref ref) {
    return settingsSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsSource>(value),
    );
  }
}

String _$settingsSourceHash() => r'f4aeea9352040a9cd54f983f66fcd02a839cbde2';

/// Changing a setting (the editor's decision).

@ProviderFor(settingsCommands)
final settingsCommandsProvider = SettingsCommandsProvider._();

/// Changing a setting (the editor's decision).

final class SettingsCommandsProvider
    extends
        $FunctionalProvider<
          SettingsCommands,
          SettingsCommands,
          SettingsCommands
        >
    with $Provider<SettingsCommands> {
  /// Changing a setting (the editor's decision).
  SettingsCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsCommandsHash();

  @$internal
  @override
  $ProviderElement<SettingsCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsCommands create(Ref ref) {
    return settingsCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsCommands>(value),
    );
  }
}

String _$settingsCommandsHash() => r'66f286740713534e69e226850dfbcb5e33ac02c4';

/// The registry and every effective value for [workspaceId] (null: the
/// platform's own view). A different person re-reads it (the provider
/// watches the session); a write invalidates it.

@ProviderFor(settingsSet)
final settingsSetProvider = SettingsSetFamily._();

/// The registry and every effective value for [workspaceId] (null: the
/// platform's own view). A different person re-reads it (the provider
/// watches the session); a write invalidates it.

final class SettingsSetProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsSet>,
          SettingsSet,
          FutureOr<SettingsSet>
        >
    with $FutureModifier<SettingsSet>, $FutureProvider<SettingsSet> {
  /// The registry and every effective value for [workspaceId] (null: the
  /// platform's own view). A different person re-reads it (the provider
  /// watches the session); a write invalidates it.
  SettingsSetProvider._({
    required SettingsSetFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'settingsSetProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$settingsSetHash();

  @override
  String toString() {
    return r'settingsSetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SettingsSet> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsSet> create(Ref ref) {
    final argument = this.argument as String?;
    return settingsSet(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SettingsSetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$settingsSetHash() => r'122934e7b6bd8bd27440d8314b3caacf01a47ddb';

/// The registry and every effective value for [workspaceId] (null: the
/// platform's own view). A different person re-reads it (the provider
/// watches the session); a write invalidates it.

final class SettingsSetFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SettingsSet>, String?> {
  SettingsSetFamily._()
    : super(
        retry: null,
        name: r'settingsSetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The registry and every effective value for [workspaceId] (null: the
  /// platform's own view). A different person re-reads it (the provider
  /// watches the session); a write invalidates it.

  SettingsSetProvider call(String? workspaceId) =>
      SettingsSetProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'settingsSetProvider';
}

/// The ACTIVE workspace's settings snapshot, for the code that works in it
/// (dunning, booking...). Re-read for a different person or workspace;
/// invalidate it after a write.

@ProviderFor(currentSettings)
final currentSettingsProvider = CurrentSettingsProvider._();

/// The ACTIVE workspace's settings snapshot, for the code that works in it
/// (dunning, booking...). Re-read for a different person or workspace;
/// invalidate it after a write.

final class CurrentSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsSet>,
          SettingsSet,
          FutureOr<SettingsSet>
        >
    with $FutureModifier<SettingsSet>, $FutureProvider<SettingsSet> {
  /// The ACTIVE workspace's settings snapshot, for the code that works in it
  /// (dunning, booking...). Re-read for a different person or workspace;
  /// invalidate it after a write.
  CurrentSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSettingsHash();

  @$internal
  @override
  $FutureProviderElement<SettingsSet> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsSet> create(Ref ref) {
    return currentSettings(ref);
  }
}

String _$currentSettingsHash() => r'2b83681b1b3f83a2fe7b1dc818cf8504dd058e2d';

/// #2589 C1 -- the active workspace's settings as an operation takes them:
/// the identity (installation, workspace, signed-in user) is fixed BEFORE the
/// read awaits, and the result is an immutable [SettingsCapture]. Signed out
/// there is nothing to capture, so the answer is null -- never another
/// person's or workspace's values.

@ProviderFor(currentSettingsCapture)
final currentSettingsCaptureProvider = CurrentSettingsCaptureProvider._();

/// #2589 C1 -- the active workspace's settings as an operation takes them:
/// the identity (installation, workspace, signed-in user) is fixed BEFORE the
/// read awaits, and the result is an immutable [SettingsCapture]. Signed out
/// there is nothing to capture, so the answer is null -- never another
/// person's or workspace's values.

final class CurrentSettingsCaptureProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingsCapture?>,
          SettingsCapture?,
          FutureOr<SettingsCapture?>
        >
    with $FutureModifier<SettingsCapture?>, $FutureProvider<SettingsCapture?> {
  /// #2589 C1 -- the active workspace's settings as an operation takes them:
  /// the identity (installation, workspace, signed-in user) is fixed BEFORE the
  /// read awaits, and the result is an immutable [SettingsCapture]. Signed out
  /// there is nothing to capture, so the answer is null -- never another
  /// person's or workspace's values.
  CurrentSettingsCaptureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSettingsCaptureProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSettingsCaptureHash();

  @$internal
  @override
  $FutureProviderElement<SettingsCapture?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingsCapture?> create(Ref ref) {
    return currentSettingsCapture(ref);
  }
}

String _$currentSettingsCaptureHash() =>
    r'90022add542c010037890661a775f57c0e20d224';
