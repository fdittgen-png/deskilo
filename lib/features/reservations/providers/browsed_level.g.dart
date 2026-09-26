// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browsed_level.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The level the member is BROWSING, shared by every view of the hub.
///
/// #1269 — it used to be three separate `State` fields: one in
/// `ReserveScreen` for the plan and the seat list, one in `DayTimeline`,
/// one in `WeekGrid`. Switching the view disposes one widget and builds
/// another, so the new one started at null and fell back to
/// `levels.first`. Choosing the second floor and tapping the day view
/// put you back on the first, every time — and choosing it again and
/// going back did it again.
///
/// One value, held above all four views, so the floor survives the
/// switch. Session-scoped on purpose: it is BROWSING state, not the
/// member's persisted default (`SelectedLevelId`, #159), which the plan
/// still reads when nothing has been browsed yet and which only an
/// explicit choice on the plan writes.
///
/// ## Why "all levels" lives here too
///
/// The day and week grids offer an "All levels" chip; the plan cannot
/// show two floors at once. Keeping the sentinel in the shared value —
/// rather than in the two grids that understand it — is what lets the
/// plan RESOLVE it without DESTROYING it: it renders a single floor
/// while the value still says "all", and going back to the day view
/// finds the chip exactly as it was left.
///
/// A view that cannot honour the value must never write over it.

@ProviderFor(BrowsedLevel)
final browsedLevelProvider = BrowsedLevelProvider._();

/// The level the member is BROWSING, shared by every view of the hub.
///
/// #1269 — it used to be three separate `State` fields: one in
/// `ReserveScreen` for the plan and the seat list, one in `DayTimeline`,
/// one in `WeekGrid`. Switching the view disposes one widget and builds
/// another, so the new one started at null and fell back to
/// `levels.first`. Choosing the second floor and tapping the day view
/// put you back on the first, every time — and choosing it again and
/// going back did it again.
///
/// One value, held above all four views, so the floor survives the
/// switch. Session-scoped on purpose: it is BROWSING state, not the
/// member's persisted default (`SelectedLevelId`, #159), which the plan
/// still reads when nothing has been browsed yet and which only an
/// explicit choice on the plan writes.
///
/// ## Why "all levels" lives here too
///
/// The day and week grids offer an "All levels" chip; the plan cannot
/// show two floors at once. Keeping the sentinel in the shared value —
/// rather than in the two grids that understand it — is what lets the
/// plan RESOLVE it without DESTROYING it: it renders a single floor
/// while the value still says "all", and going back to the day view
/// finds the chip exactly as it was left.
///
/// A view that cannot honour the value must never write over it.
final class BrowsedLevelProvider
    extends $NotifierProvider<BrowsedLevel, String?> {
  /// The level the member is BROWSING, shared by every view of the hub.
  ///
  /// #1269 — it used to be three separate `State` fields: one in
  /// `ReserveScreen` for the plan and the seat list, one in `DayTimeline`,
  /// one in `WeekGrid`. Switching the view disposes one widget and builds
  /// another, so the new one started at null and fell back to
  /// `levels.first`. Choosing the second floor and tapping the day view
  /// put you back on the first, every time — and choosing it again and
  /// going back did it again.
  ///
  /// One value, held above all four views, so the floor survives the
  /// switch. Session-scoped on purpose: it is BROWSING state, not the
  /// member's persisted default (`SelectedLevelId`, #159), which the plan
  /// still reads when nothing has been browsed yet and which only an
  /// explicit choice on the plan writes.
  ///
  /// ## Why "all levels" lives here too
  ///
  /// The day and week grids offer an "All levels" chip; the plan cannot
  /// show two floors at once. Keeping the sentinel in the shared value —
  /// rather than in the two grids that understand it — is what lets the
  /// plan RESOLVE it without DESTROYING it: it renders a single floor
  /// while the value still says "all", and going back to the day view
  /// finds the chip exactly as it was left.
  ///
  /// A view that cannot honour the value must never write over it.
  BrowsedLevelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browsedLevelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browsedLevelHash();

  @$internal
  @override
  BrowsedLevel create() => BrowsedLevel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$browsedLevelHash() => r'e27eee0448703cbf0d6cd8866732f53b623aa72a';

/// The level the member is BROWSING, shared by every view of the hub.
///
/// #1269 — it used to be three separate `State` fields: one in
/// `ReserveScreen` for the plan and the seat list, one in `DayTimeline`,
/// one in `WeekGrid`. Switching the view disposes one widget and builds
/// another, so the new one started at null and fell back to
/// `levels.first`. Choosing the second floor and tapping the day view
/// put you back on the first, every time — and choosing it again and
/// going back did it again.
///
/// One value, held above all four views, so the floor survives the
/// switch. Session-scoped on purpose: it is BROWSING state, not the
/// member's persisted default (`SelectedLevelId`, #159), which the plan
/// still reads when nothing has been browsed yet and which only an
/// explicit choice on the plan writes.
///
/// ## Why "all levels" lives here too
///
/// The day and week grids offer an "All levels" chip; the plan cannot
/// show two floors at once. Keeping the sentinel in the shared value —
/// rather than in the two grids that understand it — is what lets the
/// plan RESOLVE it without DESTROYING it: it renders a single floor
/// while the value still says "all", and going back to the day view
/// finds the chip exactly as it was left.
///
/// A view that cannot honour the value must never write over it.

abstract class _$BrowsedLevel extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
