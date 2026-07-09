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

/// Per-validator audit trail for the visible feed, keyed by event id
/// (#130). Derived from [events], so invalidating the feed refreshes it.

@ProviderFor(eventDecisions)
final eventDecisionsProvider = EventDecisionsProvider._();

/// Per-validator audit trail for the visible feed, keyed by event id
/// (#130). Derived from [events], so invalidating the feed refreshes it.

final class EventDecisionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<EventDecision>>>,
          Map<String, List<EventDecision>>,
          FutureOr<Map<String, List<EventDecision>>>
        >
    with
        $FutureModifier<Map<String, List<EventDecision>>>,
        $FutureProvider<Map<String, List<EventDecision>>> {
  /// Per-validator audit trail for the visible feed, keyed by event id
  /// (#130). Derived from [events], so invalidating the feed refreshes it.
  EventDecisionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventDecisionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventDecisionsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<EventDecision>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<EventDecision>>> create(Ref ref) {
    return eventDecisions(ref);
  }
}

String _$eventDecisionsHash() => r'34eef19c105c108c78b08f21fd487d0f3464fb9a';

/// The workspace's quorum rules (#130); empty = pre-quorum behavior.

@ProviderFor(validationPolicies)
final validationPoliciesProvider = ValidationPoliciesProvider._();

/// The workspace's quorum rules (#130); empty = pre-quorum behavior.

final class ValidationPoliciesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ValidationPolicy>>,
          List<ValidationPolicy>,
          FutureOr<List<ValidationPolicy>>
        >
    with
        $FutureModifier<List<ValidationPolicy>>,
        $FutureProvider<List<ValidationPolicy>> {
  /// The workspace's quorum rules (#130); empty = pre-quorum behavior.
  ValidationPoliciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'validationPoliciesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$validationPoliciesHash();

  @$internal
  @override
  $FutureProviderElement<List<ValidationPolicy>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ValidationPolicy>> create(Ref ref) {
    return validationPolicies(ref);
  }
}

String _$validationPoliciesHash() =>
    r'c290f85f2167ee8a475373032cf63b16296be022';

/// How many pending events await MY decision — drives the Events tab
/// badge. Same decider rule as the pending cards (#107, #130).

@ProviderFor(myPendingEventCount)
final myPendingEventCountProvider = MyPendingEventCountProvider._();

/// How many pending events await MY decision — drives the Events tab
/// badge. Same decider rule as the pending cards (#107, #130).

final class MyPendingEventCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many pending events await MY decision — drives the Events tab
  /// badge. Same decider rule as the pending cards (#107, #130).
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
    r'a099bffba84bb2d08f69ccd3c3b338d649802075';
