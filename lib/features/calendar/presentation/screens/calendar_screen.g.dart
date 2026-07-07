// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// seat/office id → display name for the active workspace.

@ProviderFor(targetNames)
final targetNamesProvider = TargetNamesProvider._();

/// seat/office id → display name for the active workspace.

final class TargetNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// seat/office id → display name for the active workspace.
  TargetNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'targetNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$targetNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return targetNames(ref);
  }
}

String _$targetNamesHash() => r'df73e2ff7e54720a61304621ca40f9b26abf26b1';
