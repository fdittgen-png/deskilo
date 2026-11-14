// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_term_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memberTermChanges)
final memberTermChangesProvider = MemberTermChangesProvider._();

final class MemberTermChangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemberTermChange>>,
          List<MemberTermChange>,
          FutureOr<List<MemberTermChange>>
        >
    with
        $FutureModifier<List<MemberTermChange>>,
        $FutureProvider<List<MemberTermChange>> {
  MemberTermChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberTermChangesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberTermChangesHash();

  @$internal
  @override
  $FutureProviderElement<List<MemberTermChange>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemberTermChange>> create(Ref ref) {
    return memberTermChanges(ref);
  }
}

String _$memberTermChangesHash() => r'2d9fb3221153181cef4f6ecebb3543b9a2d04b90';
