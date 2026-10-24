// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_reservations_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The read, one host per call through that host's own verified client;
/// the limits from the personal home's platform settings. Demo overrides
/// it with the fixture's spaces.

@ProviderFor(myReservationsRepository)
final myReservationsRepositoryProvider = MyReservationsRepositoryProvider._();

/// The read, one host per call through that host's own verified client;
/// the limits from the personal home's platform settings. Demo overrides
/// it with the fixture's spaces.

final class MyReservationsRepositoryProvider
    extends
        $FunctionalProvider<
          MyReservationsRepository,
          MyReservationsRepository,
          MyReservationsRepository
        >
    with $Provider<MyReservationsRepository> {
  /// The read, one host per call through that host's own verified client;
  /// the limits from the personal home's platform settings. Demo overrides
  /// it with the fixture's spaces.
  MyReservationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myReservationsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<MyReservationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MyReservationsRepository create(Ref ref) {
    return myReservationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MyReservationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MyReservationsRepository>(value),
    );
  }
}

String _$myReservationsRepositoryHash() =>
    r'60d3230f898a88853a7a57cd3f31e1572b624df9';

/// #2553 C3 -- View, Cancel and Check in of a row, each through the host
/// the row was read from; View reads with the same strict adapter. Demo
/// overrides it with the fixture's spaces.

@ProviderFor(myReservationActions)
final myReservationActionsProvider = MyReservationActionsProvider._();

/// #2553 C3 -- View, Cancel and Check in of a row, each through the host
/// the row was read from; View reads with the same strict adapter. Demo
/// overrides it with the fixture's spaces.

final class MyReservationActionsProvider
    extends
        $FunctionalProvider<
          MyReservationActions,
          MyReservationActions,
          MyReservationActions
        >
    with $Provider<MyReservationActions> {
  /// #2553 C3 -- View, Cancel and Check in of a row, each through the host
  /// the row was read from; View reads with the same strict adapter. Demo
  /// overrides it with the fixture's spaces.
  MyReservationActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myReservationActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationActionsHash();

  @$internal
  @override
  $ProviderElement<MyReservationActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MyReservationActions create(Ref ref) {
    return myReservationActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MyReservationActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MyReservationActions>(value),
    );
  }
}

String _$myReservationActionsHash() =>
    r'e42a4b8ef1615c603180b13a3af15b1160e60b27';

/// The personal home's limits for these reads; a registry without the
/// rows fails typed.

@ProviderFor(myReservationsLimits)
final myReservationsLimitsProvider = MyReservationsLimitsProvider._();

/// The personal home's limits for these reads; a registry without the
/// rows fails typed.

final class MyReservationsLimitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyReservationsLimits>,
          MyReservationsLimits,
          FutureOr<MyReservationsLimits>
        >
    with
        $FutureModifier<MyReservationsLimits>,
        $FutureProvider<MyReservationsLimits> {
  /// The personal home's limits for these reads; a registry without the
  /// rows fails typed.
  MyReservationsLimitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: myReservationsRetry,
        name: r'myReservationsLimitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsLimitsHash();

  @$internal
  @override
  $FutureProviderElement<MyReservationsLimits> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MyReservationsLimits> create(Ref ref) {
    return myReservationsLimits(ref);
  }
}

String _$myReservationsLimitsHash() =>
    r'1ee2e14c2cad4a16c1f0ad91e0593a698ee74626';

/// The window a person starts with and the longest one they may ask for.

@ProviderFor(MyReservationsWindowController)
final myReservationsWindowControllerProvider =
    MyReservationsWindowControllerProvider._();

/// The window a person starts with and the longest one they may ask for.
final class MyReservationsWindowControllerProvider
    extends
        $AsyncNotifierProvider<
          MyReservationsWindowController,
          MyReservationsWindow
        > {
  /// The window a person starts with and the longest one they may ask for.
  MyReservationsWindowControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: myReservationsRetry,
        name: r'myReservationsWindowControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsWindowControllerHash();

  @$internal
  @override
  MyReservationsWindowController create() => MyReservationsWindowController();
}

String _$myReservationsWindowControllerHash() =>
    r'6edf14379682ce53d947b19bf0d9b891de15ea3c';

/// The window a person starts with and the longest one they may ask for.

abstract class _$MyReservationsWindowController
    extends $AsyncNotifier<MyReservationsWindow> {
  FutureOr<MyReservationsWindow> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<MyReservationsWindow>, MyReservationsWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MyReservationsWindow>,
                MyReservationsWindow
              >,
              AsyncValue<MyReservationsWindow>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// #2553 C3 -- the period of the Past tab: by default the days that end
/// with today, read newest first; changed like the other.

@ProviderFor(MyPastReservationsWindowController)
final myPastReservationsWindowControllerProvider =
    MyPastReservationsWindowControllerProvider._();

/// #2553 C3 -- the period of the Past tab: by default the days that end
/// with today, read newest first; changed like the other.
final class MyPastReservationsWindowControllerProvider
    extends
        $AsyncNotifierProvider<
          MyPastReservationsWindowController,
          MyReservationsWindow
        > {
  /// #2553 C3 -- the period of the Past tab: by default the days that end
  /// with today, read newest first; changed like the other.
  MyPastReservationsWindowControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: myReservationsRetry,
        name: r'myPastReservationsWindowControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$myPastReservationsWindowControllerHash();

  @$internal
  @override
  MyPastReservationsWindowController create() =>
      MyPastReservationsWindowController();
}

String _$myPastReservationsWindowControllerHash() =>
    r'4e8f5f6bd8a4c87c8e9ade722d3510bd009aaa57';

/// #2553 C3 -- the period of the Past tab: by default the days that end
/// with today, read newest first; changed like the other.

abstract class _$MyPastReservationsWindowController
    extends $AsyncNotifier<MyReservationsWindow> {
  FutureOr<MyReservationsWindow> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<MyReservationsWindow>, MyReservationsWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MyReservationsWindow>,
                MyReservationsWindow
              >,
              AsyncValue<MyReservationsWindow>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// #2553 C3 -- the tab and source chosen; kept while the view is shown,
/// through a load-more or a retry.

@ProviderFor(MyReservationsFilterController)
final myReservationsFilterControllerProvider =
    MyReservationsFilterControllerProvider._();

/// #2553 C3 -- the tab and source chosen; kept while the view is shown,
/// through a load-more or a retry.
final class MyReservationsFilterControllerProvider
    extends
        $NotifierProvider<
          MyReservationsFilterController,
          MyReservationsFilter
        > {
  /// #2553 C3 -- the tab and source chosen; kept while the view is shown,
  /// through a load-more or a retry.
  MyReservationsFilterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myReservationsFilterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myReservationsFilterControllerHash();

  @$internal
  @override
  MyReservationsFilterController create() => MyReservationsFilterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MyReservationsFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MyReservationsFilter>(value),
    );
  }
}

String _$myReservationsFilterControllerHash() =>
    r'71ea342713e4987c051d2d8cd73f11577d2fd47c';

/// #2553 C3 -- the tab and source chosen; kept while the view is shown,
/// through a load-more or a retry.

abstract class _$MyReservationsFilterController
    extends $Notifier<MyReservationsFilter> {
  MyReservationsFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MyReservationsFilter, MyReservationsFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MyReservationsFilter, MyReservationsFilter>,
              MyReservationsFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The composition of one [MyReservationsQuery] (a window): every source's
/// first page read through the bounded reads, each slot emitted as soon as
/// its host answers; [loadMore] and [retry] per host.

@ProviderFor(MyReservationsComposer)
final myReservationsComposerProvider = MyReservationsComposerFamily._();

/// The composition of one [MyReservationsQuery] (a window): every source's
/// first page read through the bounded reads, each slot emitted as soon as
/// its host answers; [loadMore] and [retry] per host.
final class MyReservationsComposerProvider
    extends
        $AsyncNotifierProvider<
          MyReservationsComposer,
          MyReservationsComposition
        > {
  /// The composition of one [MyReservationsQuery] (a window): every source's
  /// first page read through the bounded reads, each slot emitted as soon as
  /// its host answers; [loadMore] and [retry] per host.
  MyReservationsComposerProvider._({
    required MyReservationsComposerFamily super.from,
    required MyReservationsQuery super.argument,
  }) : super(
         retry: myReservationsRetry,
         name: r'myReservationsComposerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myReservationsComposerHash();

  @override
  String toString() {
    return r'myReservationsComposerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MyReservationsComposer create() => MyReservationsComposer();

  @override
  bool operator ==(Object other) {
    return other is MyReservationsComposerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myReservationsComposerHash() =>
    r'4aa07db2e462acfb0e7562f26304dca9484370b5';

/// The composition of one [MyReservationsQuery] (a window): every source's
/// first page read through the bounded reads, each slot emitted as soon as
/// its host answers; [loadMore] and [retry] per host.

final class MyReservationsComposerFamily extends $Family
    with
        $ClassFamilyOverride<
          MyReservationsComposer,
          AsyncValue<MyReservationsComposition>,
          MyReservationsComposition,
          FutureOr<MyReservationsComposition>,
          MyReservationsQuery
        > {
  MyReservationsComposerFamily._()
    : super(
        retry: myReservationsRetry,
        name: r'myReservationsComposerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The composition of one [MyReservationsQuery] (a window): every source's
  /// first page read through the bounded reads, each slot emitted as soon as
  /// its host answers; [loadMore] and [retry] per host.

  MyReservationsComposerProvider call(MyReservationsQuery query) =>
      MyReservationsComposerProvider._(argument: query, from: this);

  @override
  String toString() => r'myReservationsComposerProvider';
}

/// The composition of one [MyReservationsQuery] (a window): every source's
/// first page read through the bounded reads, each slot emitted as soon as
/// its host answers; [loadMore] and [retry] per host.

abstract class _$MyReservationsComposer
    extends $AsyncNotifier<MyReservationsComposition> {
  late final _$args = ref.$arg as MyReservationsQuery;
  MyReservationsQuery get query => _$args;

  FutureOr<MyReservationsComposition> build(MyReservationsQuery query);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MyReservationsComposition>,
              MyReservationsComposition
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MyReservationsComposition>,
                MyReservationsComposition
              >,
              AsyncValue<MyReservationsComposition>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
