// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_export.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The video exporter, over the app's local file saver.

@ProviderFor(taskVideoExporter)
final taskVideoExporterProvider = TaskVideoExporterProvider._();

/// The video exporter, over the app's local file saver.

final class TaskVideoExporterProvider
    extends
        $FunctionalProvider<
          TaskVideoExporter,
          TaskVideoExporter,
          TaskVideoExporter
        >
    with $Provider<TaskVideoExporter> {
  /// The video exporter, over the app's local file saver.
  TaskVideoExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskVideoExporterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskVideoExporterHash();

  @$internal
  @override
  $ProviderElement<TaskVideoExporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaskVideoExporter create(Ref ref) {
    return taskVideoExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskVideoExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskVideoExporter>(value),
    );
  }
}

String _$taskVideoExporterHash() => r'b1ea9aab6ff2a81378887c3770ab0bcc8d42b7b0';
