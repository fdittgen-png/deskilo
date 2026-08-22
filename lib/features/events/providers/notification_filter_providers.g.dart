// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_filter_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The bell screen's filter, loaded from disk so the LAST choice greets
/// the user — across restarts (#581). Every change persists eagerly.

@ProviderFor(NotificationFilter)
final notificationFilterProvider = NotificationFilterProvider._();

/// The bell screen's filter, loaded from disk so the LAST choice greets
/// the user — across restarts (#581). Every change persists eagerly.
final class NotificationFilterProvider
    extends
        $AsyncNotifierProvider<NotificationFilter, NotificationFilterState> {
  /// The bell screen's filter, loaded from disk so the LAST choice greets
  /// the user — across restarts (#581). Every change persists eagerly.
  NotificationFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationFilterHash();

  @$internal
  @override
  NotificationFilter create() => NotificationFilter();
}

String _$notificationFilterHash() =>
    r'd5f3d22405778b5802ce41e8f0728ba798ec9b89';

/// The bell screen's filter, loaded from disk so the LAST choice greets
/// the user — across restarts (#581). Every change persists eagerly.

abstract class _$NotificationFilter
    extends $AsyncNotifier<NotificationFilterState> {
  FutureOr<NotificationFilterState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NotificationFilterState>,
              NotificationFilterState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationFilterState>,
                NotificationFilterState
              >,
              AsyncValue<NotificationFilterState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The events-seen cutoff for THIS visit: exposes the stamp from the
/// PREVIOUS bell open (what "new" is measured against) and, on
/// [markOpened], writes the current instant for the next visit — the
/// exposed value deliberately stays old so "new" rows do not vanish
/// mid-visit.

@ProviderFor(EventsSeenCutoff)
final eventsSeenCutoffProvider = EventsSeenCutoffProvider._();

/// The events-seen cutoff for THIS visit: exposes the stamp from the
/// PREVIOUS bell open (what "new" is measured against) and, on
/// [markOpened], writes the current instant for the next visit — the
/// exposed value deliberately stays old so "new" rows do not vanish
/// mid-visit.
final class EventsSeenCutoffProvider
    extends $AsyncNotifierProvider<EventsSeenCutoff, DateTime?> {
  /// The events-seen cutoff for THIS visit: exposes the stamp from the
  /// PREVIOUS bell open (what "new" is measured against) and, on
  /// [markOpened], writes the current instant for the next visit — the
  /// exposed value deliberately stays old so "new" rows do not vanish
  /// mid-visit.
  EventsSeenCutoffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsSeenCutoffProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsSeenCutoffHash();

  @$internal
  @override
  EventsSeenCutoff create() => EventsSeenCutoff();
}

String _$eventsSeenCutoffHash() => r'2a6970909433d6dbe0885406f7e281ad21c6876d';

/// The events-seen cutoff for THIS visit: exposes the stamp from the
/// PREVIOUS bell open (what "new" is measured against) and, on
/// [markOpened], writes the current instant for the next visit — the
/// exposed value deliberately stays old so "new" rows do not vanish
/// mid-visit.

abstract class _$EventsSeenCutoff extends $AsyncNotifier<DateTime?> {
  FutureOr<DateTime?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DateTime?>, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DateTime?>, DateTime?>,
              AsyncValue<DateTime?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
