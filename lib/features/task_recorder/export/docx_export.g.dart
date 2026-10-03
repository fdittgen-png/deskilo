// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'docx_export.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Word exporter, over the app's local file saver.

@ProviderFor(taskDocxExporter)
final taskDocxExporterProvider = TaskDocxExporterProvider._();

/// The Word exporter, over the app's local file saver.

final class TaskDocxExporterProvider
    extends
        $FunctionalProvider<
          TaskDocxExporter,
          TaskDocxExporter,
          TaskDocxExporter
        >
    with $Provider<TaskDocxExporter> {
  /// The Word exporter, over the app's local file saver.
  TaskDocxExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDocxExporterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDocxExporterHash();

  @$internal
  @override
  $ProviderElement<TaskDocxExporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskDocxExporter create(Ref ref) {
    return taskDocxExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskDocxExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskDocxExporter>(value),
    );
  }
}

String _$taskDocxExporterHash() => r'20ddc4103cfdb928c82567a9f567f6c432d7428d';
