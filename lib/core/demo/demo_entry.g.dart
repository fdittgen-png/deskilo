// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_entry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DemoEntry)
final demoEntryProvider = DemoEntryProvider._();

final class DemoEntryProvider extends $NotifierProvider<DemoEntry, bool> {
  DemoEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demoEntryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoEntryHash();

  @$internal
  @override
  DemoEntry create() => DemoEntry();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$demoEntryHash() => r'54519449849cf2b71863b543d256ea6f456ed8a3';

abstract class _$DemoEntry extends $Notifier<bool> {
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
