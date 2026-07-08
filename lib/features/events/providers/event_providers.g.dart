// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventRepository)
final eventRepositoryProvider = EventRepositoryProvider._();

final class EventRepositoryProvider
    extends
        $FunctionalProvider<EventRepository, EventRepository, EventRepository>
    with $Provider<EventRepository> {
  EventRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventRepositoryHash();

  @$internal
  @override
  $ProviderElement<EventRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventRepository create(Ref ref) {
    return eventRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventRepository>(value),
    );
  }
}

String _$eventRepositoryHash() => r'e23e4df7fcf2a93533c990b68c16b6a762636899';

/// The active workspace's event feed, newest first (server-scoped by role).

@ProviderFor(events)
final eventsProvider = EventsProvider._();

/// The active workspace's event feed, newest first (server-scoped by role).

final class EventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceEvent>>,
          List<WorkspaceEvent>,
          FutureOr<List<WorkspaceEvent>>
        >
    with
        $FutureModifier<List<WorkspaceEvent>>,
        $FutureProvider<List<WorkspaceEvent>> {
  /// The active workspace's event feed, newest first (server-scoped by role).
  EventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceEvent>> create(Ref ref) {
    return events(ref);
  }
}

String _$eventsHash() => r'94a3ee3da1a3fa5f32571529fc99ab264b9075af';

/// How many pending events I must decide — drives the Events tab badge.
/// Same decider rule as the pending cards (#107).

@ProviderFor(myPendingEventCount)
final myPendingEventCountProvider = MyPendingEventCountProvider._();

/// How many pending events I must decide — drives the Events tab badge.
/// Same decider rule as the pending cards (#107).

final class MyPendingEventCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many pending events I must decide — drives the Events tab badge.
  /// Same decider rule as the pending cards (#107).
  MyPendingEventCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myPendingEventCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myPendingEventCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return myPendingEventCount(ref);
  }
}

String _$myPendingEventCountHash() =>
    r'228fe5cb1618ba424913aeb8e5f2dd4414fa3214';
