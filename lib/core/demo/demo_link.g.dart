// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_link.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The link the visitor arrived with, until the demo has applied it. It
/// lives above the demo scope, like the session.

@ProviderFor(PendingDemoLink)
final pendingDemoLinkProvider = PendingDemoLinkProvider._();

/// The link the visitor arrived with, until the demo has applied it. It
/// lives above the demo scope, like the session.
final class PendingDemoLinkProvider
    extends $NotifierProvider<PendingDemoLink, DemoLink?> {
  /// The link the visitor arrived with, until the demo has applied it. It
  /// lives above the demo scope, like the session.
  PendingDemoLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingDemoLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingDemoLinkHash();

  @$internal
  @override
  PendingDemoLink create() => PendingDemoLink();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DemoLink? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DemoLink?>(value),
    );
  }
}

String _$pendingDemoLinkHash() => r'4f417b17dbb1effc9e307b2ec260a644c10bebc5';

/// The link the visitor arrived with, until the demo has applied it. It
/// lives above the demo scope, like the session.

abstract class _$PendingDemoLink extends $Notifier<DemoLink?> {
  DemoLink? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DemoLink?, DemoLink?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DemoLink?, DemoLink?>,
              DemoLink?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
