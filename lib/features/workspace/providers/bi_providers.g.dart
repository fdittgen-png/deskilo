// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(biModuleResult)
final biModuleResultProvider = BiModuleResultFamily._();

final class BiModuleResultProvider
    extends
        $FunctionalProvider<AsyncValue<BiResult>, BiResult, FutureOr<BiResult>>
    with $FutureModifier<BiResult>, $FutureProvider<BiResult> {
  BiModuleResultProvider._({
    required BiModuleResultFamily super.from,
    required (String, String, BiQueryContext) super.argument,
  }) : super(
         retry: null,
         name: r'biModuleResultProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$biModuleResultHash();

  @override
  String toString() {
    return r'biModuleResultProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<BiResult> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BiResult> create(Ref ref) {
    final argument = this.argument as (String, String, BiQueryContext);
    return biModuleResult(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is BiModuleResultProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$biModuleResultHash() => r'a24335983ceed7384b1f52c2cf59ab2441707f8d';

final class BiModuleResultFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<BiResult>,
          (String, String, BiQueryContext)
        > {
  BiModuleResultFamily._()
    : super(
        retry: null,
        name: r'biModuleResultProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BiModuleResultProvider call(
    String workspaceId,
    String moduleId,
    BiQueryContext context,
  ) => BiModuleResultProvider._(
    argument: (workspaceId, moduleId, context),
    from: this,
  );

  @override
  String toString() => r'biModuleResultProvider';
}
