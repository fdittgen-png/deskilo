// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recorder_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where recordings are kept on this device: a file per recording, or
/// the browser's own storage.

@ProviderFor(recorderLogBackend)
final recorderLogBackendProvider = RecorderLogBackendProvider._();

/// Where recordings are kept on this device: a file per recording, or
/// the browser's own storage.

final class RecorderLogBackendProvider
    extends
        $FunctionalProvider<
          RecorderLogBackend,
          RecorderLogBackend,
          RecorderLogBackend
        >
    with $Provider<RecorderLogBackend> {
  /// Where recordings are kept on this device: a file per recording, or
  /// the browser's own storage.
  RecorderLogBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderLogBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderLogBackendHash();

  @$internal
  @override
  $ProviderElement<RecorderLogBackend> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecorderLogBackend create(Ref ref) {
    return recorderLogBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecorderLogBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecorderLogBackend>(value),
    );
  }
}

String _$recorderLogBackendHash() =>
    r'e012bf02aa3eced22fe5feeded27a962a546834b';

/// The signed-in account's private recordings; null when signed out.
/// Kept alive with the recorder that reads it.

@ProviderFor(recorderStore)
final recorderStoreProvider = RecorderStoreProvider._();

/// The signed-in account's private recordings; null when signed out.
/// Kept alive with the recorder that reads it.

final class RecorderStoreProvider
    extends $FunctionalProvider<RecorderStore?, RecorderStore?, RecorderStore?>
    with $Provider<RecorderStore?> {
  /// The signed-in account's private recordings; null when signed out.
  /// Kept alive with the recorder that reads it.
  RecorderStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderStoreHash();

  @$internal
  @override
  $ProviderElement<RecorderStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecorderStore? create(Ref ref) {
    return recorderStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecorderStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecorderStore?>(value),
    );
  }
}

String _$recorderStoreHash() => r'b913b1445aae08404b45c19c041ebe5ed0cd99c3';

/// The scope a new recording would belong to; null when signed out.
/// Kept alive with the recorder that listens to it.

@ProviderFor(recorderScope)
final recorderScopeProvider = RecorderScopeProvider._();

/// The scope a new recording would belong to; null when signed out.
/// Kept alive with the recorder that listens to it.

final class RecorderScopeProvider
    extends $FunctionalProvider<RecorderScope?, RecorderScope?, RecorderScope?>
    with $Provider<RecorderScope?> {
  /// The scope a new recording would belong to; null when signed out.
  /// Kept alive with the recorder that listens to it.
  RecorderScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderScopeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderScopeHash();

  @$internal
  @override
  $ProviderElement<RecorderScope?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecorderScope? create(Ref ref) {
    return recorderScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecorderScope? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecorderScope?>(value),
    );
  }
}

String _$recorderScopeHash() => r'66244c1eb6cac2a36c033a0d9de13bd1d9207f17';

/// Whether this workspace lets its people record a task here.

@ProviderFor(taskRecorderAvailable)
final taskRecorderAvailableProvider = TaskRecorderAvailableProvider._();

/// Whether this workspace lets its people record a task here.

final class TaskRecorderAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this workspace lets its people record a task here.
  TaskRecorderAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskRecorderAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskRecorderAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return taskRecorderAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$taskRecorderAvailableHash() =>
    r'd7ddcc2ea059c759c193d9f2ac7309cae8366e8d';

/// The one recorder of this run.

@ProviderFor(recorderController)
final recorderControllerProvider = RecorderControllerProvider._();

/// The one recorder of this run.

final class RecorderControllerProvider
    extends
        $FunctionalProvider<
          RecorderController,
          RecorderController,
          RecorderController
        >
    with $Provider<RecorderController> {
  /// The one recorder of this run.
  RecorderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderControllerHash();

  @$internal
  @override
  $ProviderElement<RecorderController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecorderController create(Ref ref) {
    return recorderController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecorderController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecorderController>(value),
    );
  }
}

String _$recorderControllerHash() =>
    r'4c2ca2c1fb2c8a470621b1d0069310b5ab24f2e7';

/// The recorder's status, for the indicator and the controls.

@ProviderFor(recorderStatus)
final recorderStatusProvider = RecorderStatusProvider._();

/// The recorder's status, for the indicator and the controls.

final class RecorderStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecorderStatus>,
          RecorderStatus,
          Stream<RecorderStatus>
        >
    with $FutureModifier<RecorderStatus>, $StreamProvider<RecorderStatus> {
  /// The recorder's status, for the indicator and the controls.
  RecorderStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderStatusHash();

  @$internal
  @override
  $StreamProviderElement<RecorderStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RecorderStatus> create(Ref ref) {
    return recorderStatus(ref);
  }
}

String _$recorderStatusHash() => r'03fff5cc65bc86e003ce70bf3124a350f5af7216';

/// This account's recordings on this device, newest first.

@ProviderFor(myRecordings)
final myRecordingsProvider = MyRecordingsProvider._();

/// This account's recordings on this device, newest first.

final class MyRecordingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredRecording>>,
          List<StoredRecording>,
          FutureOr<List<StoredRecording>>
        >
    with
        $FutureModifier<List<StoredRecording>>,
        $FutureProvider<List<StoredRecording>> {
  /// This account's recordings on this device, newest first.
  MyRecordingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myRecordingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myRecordingsHash();

  @$internal
  @override
  $FutureProviderElement<List<StoredRecording>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredRecording>> create(Ref ref) {
    return myRecordings(ref);
  }
}

String _$myRecordingsHash() => r'81fc7f8c64fe893834a99c95b71bdb45fa941812';

/// Whether the recorder was opened in this run. Until it was, the
/// indicator renders its child and nothing else, and reads nothing.

@ProviderFor(RecorderOpened)
final recorderOpenedProvider = RecorderOpenedProvider._();

/// Whether the recorder was opened in this run. Until it was, the
/// indicator renders its child and nothing else, and reads nothing.
final class RecorderOpenedProvider
    extends $NotifierProvider<RecorderOpened, bool> {
  /// Whether the recorder was opened in this run. Until it was, the
  /// indicator renders its child and nothing else, and reads nothing.
  RecorderOpenedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recorderOpenedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recorderOpenedHash();

  @$internal
  @override
  RecorderOpened create() => RecorderOpened();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$recorderOpenedHash() => r'5e099faa78a8a5b2b6895089f79752531ed74d1f';

/// Whether the recorder was opened in this run. Until it was, the
/// indicator renders its child and nothing else, and reads nothing.

abstract class _$RecorderOpened extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
