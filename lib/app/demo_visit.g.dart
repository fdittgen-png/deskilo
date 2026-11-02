// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_visit.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DemoVisit)
final demoVisitProvider = DemoVisitProvider._();

final class DemoVisitProvider
    extends $NotifierProvider<DemoVisit, DemoOrigin?> {
  DemoVisitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demoVisitProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoVisitHash();

  @$internal
  @override
  DemoVisit create() => DemoVisit();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DemoOrigin? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DemoOrigin?>(value),
    );
  }
}

String _$demoVisitHash() => r'f4dcd8f4f00af8d479b5ec51119eb8da97752382';

abstract class _$DemoVisit extends $Notifier<DemoOrigin?> {
  DemoOrigin? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DemoOrigin?, DemoOrigin?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DemoOrigin?, DemoOrigin?>,
              DemoOrigin?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
