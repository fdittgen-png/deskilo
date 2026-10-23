// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_step_timing_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Records the sessions on setup step pages and reports the ones that
/// finished their step. One per app: a page reports to it on opening and
/// on leaving, and it reads the status whenever the guide does.

@ProviderFor(SetupStepTimingRecorder)
final setupStepTimingRecorderProvider = SetupStepTimingRecorderProvider._();

/// Records the sessions on setup step pages and reports the ones that
/// finished their step. One per app: a page reports to it on opening and
/// on leaving, and it reads the status whenever the guide does.
final class SetupStepTimingRecorderProvider
    extends $NotifierProvider<SetupStepTimingRecorder, void> {
  /// Records the sessions on setup step pages and reports the ones that
  /// finished their step. One per app: a page reports to it on opening and
  /// on leaving, and it reads the status whenever the guide does.
  SetupStepTimingRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupStepTimingRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupStepTimingRecorderHash();

  @$internal
  @override
  SetupStepTimingRecorder create() => SetupStepTimingRecorder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$setupStepTimingRecorderHash() =>
    r'23863fe4172066ad7674115205af82243440b116';

/// Records the sessions on setup step pages and reports the ones that
/// finished their step. One per app: a page reports to it on opening and
/// on leaving, and it reads the status whenever the guide does.

abstract class _$SetupStepTimingRecorder extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
