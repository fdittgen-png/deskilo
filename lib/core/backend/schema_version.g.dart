// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(schemaVersionSource)
final schemaVersionSourceProvider = SchemaVersionSourceProvider._();

final class SchemaVersionSourceProvider
    extends
        $FunctionalProvider<
          SchemaVersionSource,
          SchemaVersionSource,
          SchemaVersionSource
        >
    with $Provider<SchemaVersionSource> {
  SchemaVersionSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaVersionSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaVersionSourceHash();

  @$internal
  @override
  $ProviderElement<SchemaVersionSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SchemaVersionSource create(Ref ref) {
    return schemaVersionSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SchemaVersionSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SchemaVersionSource>(value),
    );
  }
}

String _$schemaVersionSourceHash() =>
    r'bb819981102249367c74eaf3a59b3d83f53126e7';

/// How this device's server compares with this build — asked once per
/// process, like the endpoint itself, which only changes at the next start.
///
/// Fails OPEN on silence: [SchemaCompatibility.unknown] never blocks, so
/// an offline start behaves exactly as it did before the gate existed.
///
/// #3885 — silence is not a verdict: while it is [SchemaCompatibility.unknown]
/// the question is asked once more each time the app comes back to the
/// foreground (an event, never a timer). A known verdict is not asked again.

@ProviderFor(schemaCompatibility)
final schemaCompatibilityProvider = SchemaCompatibilityProvider._();

/// How this device's server compares with this build — asked once per
/// process, like the endpoint itself, which only changes at the next start.
///
/// Fails OPEN on silence: [SchemaCompatibility.unknown] never blocks, so
/// an offline start behaves exactly as it did before the gate existed.
///
/// #3885 — silence is not a verdict: while it is [SchemaCompatibility.unknown]
/// the question is asked once more each time the app comes back to the
/// foreground (an event, never a timer). A known verdict is not asked again.

final class SchemaCompatibilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<SchemaCompatibility>,
          SchemaCompatibility,
          FutureOr<SchemaCompatibility>
        >
    with
        $FutureModifier<SchemaCompatibility>,
        $FutureProvider<SchemaCompatibility> {
  /// How this device's server compares with this build — asked once per
  /// process, like the endpoint itself, which only changes at the next start.
  ///
  /// Fails OPEN on silence: [SchemaCompatibility.unknown] never blocks, so
  /// an offline start behaves exactly as it did before the gate existed.
  ///
  /// #3885 — silence is not a verdict: while it is [SchemaCompatibility.unknown]
  /// the question is asked once more each time the app comes back to the
  /// foreground (an event, never a timer). A known verdict is not asked again.
  SchemaCompatibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaCompatibilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaCompatibilityHash();

  @$internal
  @override
  $FutureProviderElement<SchemaCompatibility> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SchemaCompatibility> create(Ref ref) {
    return schemaCompatibility(ref);
  }
}

String _$schemaCompatibilityHash() =>
    r'b25618f97d2ea7425ee1f521dd7d2c4a5943aa49';
