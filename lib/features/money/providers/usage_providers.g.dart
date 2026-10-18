// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #833 — which month the Usage face is showing, and whose records.
/// A member only ever sees their own, so the id is ignored for them by
/// the server; an issuer uses it to narrow to one person.

@ProviderFor(UsageFilter)
final usageFilterProvider = UsageFilterProvider._();

/// #833 — which month the Usage face is showing, and whose records.
/// A member only ever sees their own, so the id is ignored for them by
/// the server; an issuer uses it to narrow to one person.
final class UsageFilterProvider
    extends
        $NotifierProvider<UsageFilter, ({String? memberId, String? period})> {
  /// #833 — which month the Usage face is showing, and whose records.
  /// A member only ever sees their own, so the id is ignored for them by
  /// the server; an issuer uses it to narrow to one person.
  UsageFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageFilterHash();

  @$internal
  @override
  UsageFilter create() => UsageFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String? memberId, String? period}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({String? memberId, String? period})>(value),
    );
  }
}

String _$usageFilterHash() => r'c58a2b0cccf1426c4bbfd4da3c3050cda2d73d25';

/// #833 — which month the Usage face is showing, and whose records.
/// A member only ever sees their own, so the id is ignored for them by
/// the server; an issuer uses it to narrow to one person.

abstract class _$UsageFilter
    extends $Notifier<({String? memberId, String? period})> {
  ({String? memberId, String? period}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String? memberId, String? period}),
              ({String? memberId, String? period})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String? memberId, String? period}),
                ({String? memberId, String? period})
              >,
              ({String? memberId, String? period}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// #2590 — one month of usage as a PURE read, with how complete it is: it
/// records nothing, and a month nobody has recorded reads as incomplete.

@ProviderFor(usageRead)
final usageReadProvider = UsageReadFamily._();

/// #2590 — one month of usage as a PURE read, with how complete it is: it
/// records nothing, and a month nobody has recorded reads as incomplete.

final class UsageReadProvider
    extends
        $FunctionalProvider<
          AsyncValue<UsageRead>,
          UsageRead,
          FutureOr<UsageRead>
        >
    with $FutureModifier<UsageRead>, $FutureProvider<UsageRead> {
  /// #2590 — one month of usage as a PURE read, with how complete it is: it
  /// records nothing, and a month nobody has recorded reads as incomplete.
  UsageReadProvider._({
    required UsageReadFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'usageReadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usageReadHash();

  @override
  String toString() {
    return r'usageReadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UsageRead> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UsageRead> create(Ref ref) {
    final argument = this.argument as String;
    return usageRead(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UsageReadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usageReadHash() => r'ee4491b9b3ddeb780151fcfe436f5efbe83dfe5c';

/// #2590 — one month of usage as a PURE read, with how complete it is: it
/// records nothing, and a month nobody has recorded reads as incomplete.

final class UsageReadFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UsageRead>, String> {
  UsageReadFamily._()
    : super(
        retry: null,
        name: r'usageReadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #2590 — one month of usage as a PURE read, with how complete it is: it
  /// records nothing, and a month nobody has recorded reads as incomplete.

  UsageReadProvider call(String period) =>
      UsageReadProvider._(argument: period, from: this);

  @override
  String toString() => r'usageReadProvider';
}
