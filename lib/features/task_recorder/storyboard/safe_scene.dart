// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the allow-listed presentation model an illustration is drawn
// from.
//
// A scene is NOT a picture of the app. It is a short list of generic
// controls — an app bar, chips, a segmented choice, synthetic desks,
// field rows, buttons — whose labels come from a fixed set of localized
// strings and whose selections come from the recording's vocabulary
// values (safe_payload.dart). It is built before any pixel exists, from
// the recording alone: no repository, provider, network, image,
// avatar, member name, plan drawing or typed value can reach it,
// because nothing here can hold one. Desks are named A1…B4 whatever the
// real workspace calls them.
import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import '../domain/task_recording.dart';
import 'storyboard.dart';

/// The screens a scene can stand for.
enum SceneScreen { reserve, bookingSheet, reservationDetail }

/// The generic controls a scene is made of.
enum SceneElementKind {
  appBar,
  chip,
  segment,
  desk,
  listRow,
  sheet,
  fieldRow,
  button,
  card,
  backButton,
}

/// One control. [label] and [value] come from [SceneLabels] only.
class SceneElement {
  const SceneElement(
    this.kind,
    this.rect, {
    this.label = '',
    this.value = '',
    this.selected = false,
    this.highlighted = false,
  });

  final SceneElementKind kind;
  final NormalizedRect rect;
  final String label;
  final String value;
  final bool selected;
  final bool highlighted;

  @override
  bool operator ==(Object other) =>
      other is SceneElement &&
      other.kind == kind &&
      other.rect == rect &&
      other.label == label &&
      other.value == value &&
      other.selected == selected &&
      other.highlighted == highlighted;

  @override
  int get hashCode =>
      Object.hash(kind, rect, label, value, selected, highlighted);
}

/// An illustration's content.
class SafeScene {
  SafeScene(this.screen, List<SceneElement> elements)
    : elements = List.unmodifiable(elements);

  final SceneScreen screen;
  final List<SceneElement> elements;

  /// The emphasised control's rectangle, if any.
  NormalizedRect? get highlight =>
      elements.where((e) => e.highlighted).firstOrNull?.rect;

  /// Every text the scene can draw: what a privacy test inspects.
  Iterable<String> get texts sync* {
    for (final e in elements) {
      if (e.label.isNotEmpty) yield e.label;
      if (e.value.isNotEmpty) yield e.value;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SafeScene &&
      other.screen == screen &&
      other.elements.length == elements.length &&
      Iterable<int>.generate(elements.length)
          .every((i) => other.elements[i] == elements[i]);

  @override
  int get hashCode => Object.hash(screen, Object.hashAll(elements));
}

/// The closed set of words a scene may draw, in one language.
class SceneLabels {
  SceneLabels(AppLocalizations l)
    : reserve = l.shellReserveButton,
      today = l.calendarToday,
      tomorrow = l.calendarTomorrow,
      later = l.taskExportSceneLater,
      fullDay = l.reserveFullDayChip,
      morning = l.planMorningChip,
      afternoon = l.planAfternoonChip,
      plan = l.tabPlan,
      list = l.portalList,
      bookingTitle = l.taskExportSceneBookingTitle,
      detailTitle = l.taskExportSceneDetailTitle,
      confirm = l.taskExportSceneConfirm,
      cancel = l.taskExportSceneCancel,
      forWhom = l.taskExportFieldForWhom,
      repeat = l.taskExportFieldRepeat,
      checkIn = l.taskExportFieldCheckIn,
      time = l.taskExportFieldTime,
      accessories = l.taskExportFieldAccessories,
      self = l.taskExportValueSelf,
      otherMember = l.taskExportValueOtherMember,
      once = l.taskExportValueOnce,
      series = l.taskExportValueSeries,
      yes = l.taskExportValueYes,
      no = l.taskExportValueNo,
      desk = l.taskExportValueDesk,
      room = l.taskExportValueRoom,
      provenance = l.taskExportSceneProvenance;

  final String reserve, today, tomorrow, later, fullDay, morning, afternoon;
  final String plan, list, bookingTitle, detailTitle, confirm, cancel;
  final String forWhom, repeat, checkIn, time, accessories;
  final String self, otherMember, once, series, yes, no, desk, room;

  /// Drawn on every recreated illustration.
  final String provenance;

  /// Synthetic place names: never the workspace's own.
  static const places = ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'];

  /// Every word a scene may draw.
  Set<String> get all => {
    reserve,
    today,
    tomorrow,
    later,
    fullDay,
    morning,
    afternoon,
    plan,
    list,
    bookingTitle,
    detailTitle,
    confirm,
    cancel,
    forWhom,
    repeat,
    checkIn,
    time,
    accessories,
    self,
    otherMember,
    once,
    series,
    yes,
    no,
    desk,
    room,
    '—',
    '‹',
    ...places,
  };
}

/// What the recording has chosen so far, as vocabulary values only.
class _State {
  String? date, period, view, resource, forWhom, repeat, checkIn;
  bool placeChosen = false;

  void absorb(RecordedStep s) {
    String? v(String key) {
      final value = s.payload.values[key];
      return value == null || value == 'withheld' ? null : value;
    }

    date = v('date_relation') ?? date;
    period = v('period') ?? period;
    view = v('view_mode') ?? view;
    resource = v('resource_kind') ?? resource;
    forWhom = v('for_whom') ?? forWhom;
    repeat = v('repeat') ?? repeat;
    checkIn = v('check_in') ?? checkIn;
    if (s.action == RecorderActions.selectResource) placeChosen = true;
  }
}

/// The scenes of a recording, one per step (null where the step gets a
/// text slide or an exclusion card). Built from identifiers and
/// vocabulary values alone.
List<SafeScene?> buildScenes(TaskRecording r, SceneLabels labels) {
  final state = _State();
  final out = <SafeScene?>[];
  for (final s in r.steps) {
    if (s.kind != StepKind.action) {
      out.add(null);
      continue;
    }
    state.absorb(s);
    out.add(_scene(s, state, labels));
  }
  return out;
}

NormalizedRect _r(double l, double t, double w, double h) =>
    NormalizedRect(l, t, w, h);

SafeScene? _scene(RecordedStep s, _State st, SceneLabels w) {
  final a = s.action;
  switch (s.surface) {
    case RecorderSurfaces.reserve:
      return _reserve(st, w, a);
    case RecorderSurfaces.bookingSheet:
      return _sheet(st, w, a, s.target);
    case RecorderSurfaces.reservationDetail:
      return _detail(st, w, a);
    case 'navigation.any' when a == RecorderActions.back:
      return _detail(st, w, a);
    default:
      return null;
  }
}

SafeScene _reserve(_State st, SceneLabels w, String? a) {
  final dateIndex = switch (st.date) {
    null => -1,
    'today' => 0,
    'tomorrow' => 1,
    _ => 2,
  };
  final periodIndex = switch (st.period) {
    'full_day' => 0,
    'morning' => 1,
    'afternoon' => 2,
    _ => -1,
  };
  final list = st.view == 'list';
  final hDate = a == RecorderActions.selectDate;
  final hPeriod = a == RecorderActions.selectPeriod;
  final hView = a == RecorderActions.switchView;
  final hPlace = a == RecorderActions.selectResource;
  return SafeScene(SceneScreen.reserve, [
    SceneElement(
      SceneElementKind.appBar,
      _r(0, 0, 1, 0.11),
      label: w.reserve,
      highlighted: a == RecorderActions.openReserve,
    ),
    for (final (i, label) in [w.today, w.tomorrow, w.later].indexed)
      SceneElement(
        SceneElementKind.chip,
        _r(0.04 + i * 0.2, 0.15, 0.18, 0.08),
        label: label,
        selected: i == dateIndex,
        highlighted: hDate && i == dateIndex,
      ),
    for (final (i, label) in [w.fullDay, w.morning, w.afternoon].indexed)
      SceneElement(
        SceneElementKind.segment,
        _r(0.04 + i * 0.18, 0.28, 0.18, 0.08),
        label: label,
        selected: i == periodIndex,
        highlighted: hPeriod && i == periodIndex,
      ),
    for (final (i, label) in [w.plan, w.list].indexed)
      SceneElement(
        SceneElementKind.segment,
        _r(0.72 + i * 0.12, 0.28, 0.12, 0.08),
        label: label,
        selected: list == (i == 1),
        highlighted: hView && list == (i == 1),
      ),
    if (list)
      for (final (i, place) in SceneLabels.places.take(4).indexed)
        SceneElement(
          SceneElementKind.listRow,
          _r(0.04, 0.42 + i * 0.13, 0.92, 0.11),
          label: place,
          value: w.desk,
          selected: st.placeChosen && i == 1,
          highlighted: hPlace && i == 1,
        )
    else
      for (final (i, place) in SceneLabels.places.indexed)
        SceneElement(
          SceneElementKind.desk,
          _r(0.08 + (i % 4) * 0.22, 0.44 + (i ~/ 4) * 0.26, 0.16, 0.2),
          label: place,
          selected: st.placeChosen && i == 1,
          highlighted: hPlace && i == 1,
        ),
  ]);
}

SafeScene _sheet(_State st, SceneLabels w, String? a, String? target) {
  String value(String? v, Map<String, String> words) => words[v] ?? '—';
  final rows = [
    (
      'for_whom',
      w.forWhom,
      value(st.forWhom, {'self': w.self, 'other_member': w.otherMember}),
    ),
    (
      'repeat',
      w.repeat,
      value(st.repeat, {'once': w.once, 'series': w.series}),
    ),
    ('check_in', w.checkIn, value(st.checkIn, {'yes': w.yes, 'no': w.no})),
    ('time', w.time, '—'),
    ('accessories', w.accessories, '—'),
  ];
  final field = a == RecorderActions.changeBookingField ? target : null;
  return SafeScene(SceneScreen.bookingSheet, [
    SceneElement(
      SceneElementKind.sheet,
      _r(0.1, 0.08, 0.8, 0.92),
      label: w.bookingTitle,
    ),
    for (final (i, (key, label, v)) in rows.indexed)
      SceneElement(
        SceneElementKind.fieldRow,
        _r(0.14, 0.2 + i * 0.12, 0.72, 0.1),
        label: label,
        value: v,
        highlighted: key == field,
      ),
    SceneElement(
      SceneElementKind.button,
      _r(0.14, 0.84, 0.34, 0.1),
      label: w.cancel,
      highlighted: a == RecorderActions.cancelReview,
    ),
    SceneElement(
      SceneElementKind.button,
      _r(0.52, 0.84, 0.34, 0.1),
      label: w.confirm,
      selected: true,
      highlighted: a == RecorderActions.confirmBooking,
    ),
  ]);
}

SafeScene _detail(_State st, SceneLabels w, String? a) {
  final date = switch (st.date) {
    'today' => w.today,
    'tomorrow' => w.tomorrow,
    null => '—',
    _ => w.later,
  };
  final period = switch (st.period) {
    'full_day' => w.fullDay,
    'morning' => w.morning,
    'afternoon' => w.afternoon,
    _ => '—',
  };
  return SafeScene(SceneScreen.reservationDetail, [
    SceneElement(
      SceneElementKind.appBar,
      _r(0, 0, 1, 0.11),
      label: w.detailTitle,
    ),
    SceneElement(
      SceneElementKind.backButton,
      _r(0.01, 0.015, 0.07, 0.08),
      label: '‹',
      highlighted: a == RecorderActions.back,
    ),
    SceneElement(
      SceneElementKind.card,
      _r(0.1, 0.2, 0.8, 0.5),
      label: SceneLabels.places[1],
      value: '$date · $period · ${st.resource == 'room' ? w.room : w.desk}',
      highlighted: a == RecorderActions.viewDetails,
    ),
  ]);
}
