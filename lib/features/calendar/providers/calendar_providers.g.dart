// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(calendarRepository)
final calendarRepositoryProvider = CalendarRepositoryProvider._();

final class CalendarRepositoryProvider
    extends
        $FunctionalProvider<
          CalendarRepository,
          CalendarRepository,
          CalendarRepository
        >
    with $Provider<CalendarRepository> {
  CalendarRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarRepositoryHash();

  @$internal
  @override
  $ProviderElement<CalendarRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarRepository create(Ref ref) {
    return calendarRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarRepository>(value),
    );
  }
}

String _$calendarRepositoryHash() =>
    r'71151aedcc6f5602a7400097f69feed0f4f7b2d0';

/// One range of the hub (#718), cached per [query] — a re-tap of the
/// same day costs nothing, a different day is a different key. Realtime
/// invalidates the whole family when any dated table changes, so a
/// booking made on another device lands in the open range too.

@ProviderFor(calendarItems)
final calendarItemsProvider = CalendarItemsFamily._();

/// One range of the hub (#718), cached per [query] — a re-tap of the
/// same day costs nothing, a different day is a different key. Realtime
/// invalidates the whole family when any dated table changes, so a
/// booking made on another device lands in the open range too.

final class CalendarItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CalendarPage>,
          CalendarPage,
          FutureOr<CalendarPage>
        >
    with $FutureModifier<CalendarPage>, $FutureProvider<CalendarPage> {
  /// One range of the hub (#718), cached per [query] — a re-tap of the
  /// same day costs nothing, a different day is a different key. Realtime
  /// invalidates the whole family when any dated table changes, so a
  /// booking made on another device lands in the open range too.
  CalendarItemsProvider._({
    required CalendarItemsFamily super.from,
    required CalendarQuery super.argument,
  }) : super(
         retry: null,
         name: r'calendarItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarItemsHash();

  @override
  String toString() {
    return r'calendarItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CalendarPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CalendarPage> create(Ref ref) {
    final argument = this.argument as CalendarQuery;
    return calendarItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarItemsHash() => r'6783381c7cf13e3492d303c07974376de24722a9';

/// One range of the hub (#718), cached per [query] — a re-tap of the
/// same day costs nothing, a different day is a different key. Realtime
/// invalidates the whole family when any dated table changes, so a
/// booking made on another device lands in the open range too.

final class CalendarItemsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CalendarPage>, CalendarQuery> {
  CalendarItemsFamily._()
    : super(
        retry: null,
        name: r'calendarItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One range of the hub (#718), cached per [query] — a re-tap of the
  /// same day costs nothing, a different day is a different key. Realtime
  /// invalidates the whole family when any dated table changes, so a
  /// booking made on another device lands in the open range too.

  CalendarItemsProvider call(CalendarQuery query) =>
      CalendarItemsProvider._(argument: query, from: this);

  @override
  String toString() => r'calendarItemsProvider';
}

/// Who could look at my data (#719).

@ProviderFor(whoCanAccessMe)
final whoCanAccessMeProvider = WhoCanAccessMeProvider._();

/// Who could look at my data (#719).

final class WhoCanAccessMeProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccessMap>,
          AccessMap,
          FutureOr<AccessMap>
        >
    with $FutureModifier<AccessMap>, $FutureProvider<AccessMap> {
  /// Who could look at my data (#719).
  WhoCanAccessMeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoCanAccessMeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoCanAccessMeHash();

  @$internal
  @override
  $FutureProviderElement<AccessMap> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AccessMap> create(Ref ref) {
    return whoCanAccessMe(ref);
  }
}

String _$whoCanAccessMeHash() => r'342cb13f4c9166094c6d6dea33dbc4476ab317c7';

/// Who DID look (#719): rows about me, or the workspace's for a member
/// who manages members — the server decides which.

@ProviderFor(dataAccessLog)
final dataAccessLogProvider = DataAccessLogProvider._();

/// Who DID look (#719): rows about me, or the workspace's for a member
/// who manages members — the server decides which.

final class DataAccessLogProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DataAccessEntry>>,
          List<DataAccessEntry>,
          FutureOr<List<DataAccessEntry>>
        >
    with
        $FutureModifier<List<DataAccessEntry>>,
        $FutureProvider<List<DataAccessEntry>> {
  /// Who DID look (#719): rows about me, or the workspace's for a member
  /// who manages members — the server decides which.
  DataAccessLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataAccessLogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataAccessLogHash();

  @$internal
  @override
  $FutureProviderElement<List<DataAccessEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DataAccessEntry>> create(Ref ref) {
    return dataAccessLog(ref);
  }
}

String _$dataAccessLogHash() => r'efd59c65199d5a51a35cb00418c75d51215b9e8b';
