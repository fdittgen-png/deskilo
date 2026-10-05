// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GuideSession)
final guideSessionProvider = GuideSessionProvider._();

final class GuideSessionProvider
    extends $NotifierProvider<GuideSession, GuideSessionState> {
  GuideSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideSessionHash();

  @$internal
  @override
  GuideSession create() => GuideSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideSessionState>(value),
    );
  }
}

String _$guideSessionHash() => r'81cf196ffbb1722a92c3f287e201e4a0eafadafc';

abstract class _$GuideSession extends $Notifier<GuideSessionState> {
  GuideSessionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GuideSessionState, GuideSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GuideSessionState, GuideSessionState>,
              GuideSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
