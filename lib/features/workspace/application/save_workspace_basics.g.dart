// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_workspace_basics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2870 — the basics step's save.

@ProviderFor(saveWorkspaceBasics)
final saveWorkspaceBasicsProvider = SaveWorkspaceBasicsProvider._();

/// #2870 — the basics step's save.

final class SaveWorkspaceBasicsProvider
    extends
        $FunctionalProvider<
          SaveWorkspaceBasics,
          SaveWorkspaceBasics,
          SaveWorkspaceBasics
        >
    with $Provider<SaveWorkspaceBasics> {
  /// #2870 — the basics step's save.
  SaveWorkspaceBasicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveWorkspaceBasicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveWorkspaceBasicsHash();

  @$internal
  @override
  $ProviderElement<SaveWorkspaceBasics> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveWorkspaceBasics create(Ref ref) {
    return saveWorkspaceBasics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveWorkspaceBasics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveWorkspaceBasics>(value),
    );
  }
}

String _$saveWorkspaceBasicsHash() =>
    r'9c51c29325d6ed91eef24ab6323ac606b9bc8839';
