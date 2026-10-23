// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_data_commands.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 0546 — the sample data commands of the selected server.

@ProviderFor(sampleDataCommands)
final sampleDataCommandsProvider = SampleDataCommandsProvider._();

/// 0546 — the sample data commands of the selected server.

final class SampleDataCommandsProvider
    extends
        $FunctionalProvider<
          SampleDataCommands,
          SampleDataCommands,
          SampleDataCommands
        >
    with $Provider<SampleDataCommands> {
  /// 0546 — the sample data commands of the selected server.
  SampleDataCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleDataCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleDataCommandsHash();

  @$internal
  @override
  $ProviderElement<SampleDataCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SampleDataCommands create(Ref ref) {
    return sampleDataCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SampleDataCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SampleDataCommands>(value),
    );
  }
}

String _$sampleDataCommandsHash() =>
    r'071ba8e1c0ab6a06c4c3d0736757380f132a2eec';
