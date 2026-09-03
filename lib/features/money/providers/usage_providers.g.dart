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
  void runBuild() {
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
    element.handleCreate(ref, build);
  }
}

/// One month of usage records. The server backfills the month's
/// no-shows before answering, so reading a month is what makes its
/// uncounted bookings appear — there is no cron behind this.

@ProviderFor(usageRecords)
final usageRecordsProvider = UsageRecordsFamily._();

/// One month of usage records. The server backfills the month's
/// no-shows before answering, so reading a month is what makes its
/// uncounted bookings appear — there is no cron behind this.

final class UsageRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UsageRecord>>,
          List<UsageRecord>,
          FutureOr<List<UsageRecord>>
        >
    with
        $FutureModifier<List<UsageRecord>>,
        $FutureProvider<List<UsageRecord>> {
  /// One month of usage records. The server backfills the month's
  /// no-shows before answering, so reading a month is what makes its
  /// uncounted bookings appear — there is no cron behind this.
  UsageRecordsProvider._({
    required UsageRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'usageRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usageRecordsHash();

  @override
  String toString() {
    return r'usageRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<UsageRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UsageRecord>> create(Ref ref) {
    final argument = this.argument as String;
    return usageRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UsageRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usageRecordsHash() => r'f1fe6c8d125200e7a519762bb6a662b69ae5a944';

/// One month of usage records. The server backfills the month's
/// no-shows before answering, so reading a month is what makes its
/// uncounted bookings appear — there is no cron behind this.

final class UsageRecordsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<UsageRecord>>, String> {
  UsageRecordsFamily._()
    : super(
        retry: null,
        name: r'usageRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One month of usage records. The server backfills the month's
  /// no-shows before answering, so reading a month is what makes its
  /// uncounted bookings appear — there is no cron behind this.

  UsageRecordsProvider call(String period) =>
      UsageRecordsProvider._(argument: period, from: this);

  @override
  String toString() => r'usageRecordsProvider';
}
