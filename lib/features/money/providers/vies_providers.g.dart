// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vies_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(viesRepository)
final viesRepositoryProvider = ViesRepositoryProvider._();

final class ViesRepositoryProvider
    extends $FunctionalProvider<ViesRepository, ViesRepository, ViesRepository>
    with $Provider<ViesRepository> {
  ViesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ViesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ViesRepository create(Ref ref) {
    return viesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViesRepository>(value),
    );
  }
}

String _$viesRepositoryHash() => r'2a74115c979ffd6d6f88e2d261ed3cf0f38f1d11';

/// Checking a number now (the decision the member page asks for).

@ProviderFor(checkVies)
final checkViesProvider = CheckViesProvider._();

/// Checking a number now (the decision the member page asks for).

final class CheckViesProvider
    extends $FunctionalProvider<CheckVies, CheckVies, CheckVies>
    with $Provider<CheckVies> {
  /// Checking a number now (the decision the member page asks for).
  CheckViesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkViesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkViesHash();

  @$internal
  @override
  $ProviderElement<CheckVies> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CheckVies create(Ref ref) {
    return checkVies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckVies value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckVies>(value),
    );
  }
}

String _$checkViesHash() => r'4ad2248461854580e709d90ad81b495c40d429df';

/// The last check of one member's VAT number.

@ProviderFor(memberViesCheck)
final memberViesCheckProvider = MemberViesCheckFamily._();

/// The last check of one member's VAT number.

final class MemberViesCheckProvider
    extends
        $FunctionalProvider<
          AsyncValue<ViesCheck>,
          ViesCheck,
          FutureOr<ViesCheck>
        >
    with $FutureModifier<ViesCheck>, $FutureProvider<ViesCheck> {
  /// The last check of one member's VAT number.
  MemberViesCheckProvider._({
    required MemberViesCheckFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberViesCheckProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberViesCheckHash();

  @override
  String toString() {
    return r'memberViesCheckProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ViesCheck> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ViesCheck> create(Ref ref) {
    final argument = this.argument as String;
    return memberViesCheck(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberViesCheckProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberViesCheckHash() => r'247c11497c493137cac03d4e3d6f53d0ff0b27b1';

/// The last check of one member's VAT number.

final class MemberViesCheckFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ViesCheck>, String> {
  MemberViesCheckFamily._()
    : super(
        retry: null,
        name: r'memberViesCheckProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The last check of one member's VAT number.

  MemberViesCheckProvider call(String memberId) =>
      MemberViesCheckProvider._(argument: memberId, from: this);

  @override
  String toString() => r'memberViesCheckProvider';
}
