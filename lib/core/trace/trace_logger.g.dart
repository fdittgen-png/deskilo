// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trace_logger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide trace logger. Bootstrap replaces [TraceLogger.instance] with a
/// file-backed logger before `runApp`; this provider simply exposes it so
/// widgets and tests share one injection point.

@ProviderFor(traceLogger)
final traceLoggerProvider = TraceLoggerProvider._();

/// App-wide trace logger. Bootstrap replaces [TraceLogger.instance] with a
/// file-backed logger before `runApp`; this provider simply exposes it so
/// widgets and tests share one injection point.

final class TraceLoggerProvider
    extends $FunctionalProvider<TraceLogger, TraceLogger, TraceLogger>
    with $Provider<TraceLogger> {
  /// App-wide trace logger. Bootstrap replaces [TraceLogger.instance] with a
  /// file-backed logger before `runApp`; this provider simply exposes it so
  /// widgets and tests share one injection point.
  TraceLoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'traceLoggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$traceLoggerHash();

  @$internal
  @override
  $ProviderElement<TraceLogger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TraceLogger create(Ref ref) {
    return traceLogger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TraceLogger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TraceLogger>(value),
    );
  }
}

String _$traceLoggerHash() => r'50afb721ecb65c75f1e464b6a89bee0e1611db7f';
