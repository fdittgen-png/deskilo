// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connected_space_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Enters workspaces of connected installations. Only the latest entry may
/// select: an answer that arrives after a newer request (installation A
/// after the person chose B) selects nothing.

@ProviderFor(ConnectedSpaceEntry)
final connectedSpaceEntryProvider = ConnectedSpaceEntryProvider._();

/// Enters workspaces of connected installations. Only the latest entry may
/// select: an answer that arrives after a newer request (installation A
/// after the person chose B) selects nothing.
final class ConnectedSpaceEntryProvider
    extends $NotifierProvider<ConnectedSpaceEntry, void> {
  /// Enters workspaces of connected installations. Only the latest entry may
  /// select: an answer that arrives after a newer request (installation A
  /// after the person chose B) selects nothing.
  ConnectedSpaceEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectedSpaceEntryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectedSpaceEntryHash();

  @$internal
  @override
  ConnectedSpaceEntry create() => ConnectedSpaceEntry();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$connectedSpaceEntryHash() =>
    r'61b95e78ec6b207d4b47c79c270ec23e12434840';

/// Enters workspaces of connected installations. Only the latest entry may
/// select: an answer that arrives after a newer request (installation A
/// after the person chose B) selects nothing.

abstract class _$ConnectedSpaceEntry extends $Notifier<void> {
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
