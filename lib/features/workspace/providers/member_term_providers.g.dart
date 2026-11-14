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

@ProviderFor(memberInvoicedMonths)
final memberInvoicedMonthsProvider = MemberInvoicedMonthsProvider._();

final class MemberInvoicedMonthsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Set<DateTime>>>,
          Map<String, Set<DateTime>>,
          FutureOr<Map<String, Set<DateTime>>>
        >
    with
        $FutureModifier<Map<String, Set<DateTime>>>,
        $FutureProvider<Map<String, Set<DateTime>>> {
  MemberInvoicedMonthsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberInvoicedMonthsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberInvoicedMonthsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Set<DateTime>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Set<DateTime>>> create(Ref ref) {
    return memberInvoicedMonths(ref);
  }
}

String _$memberInvoicedMonthsHash() =>
    r'de19058c3941ca29f6d15d5f79f99d50697b6be8';
