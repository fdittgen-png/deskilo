// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the onboarding recipes' measuring seam: the same runner, the
// same record (`report/perf.psv`) and the same meter as the journeys in
// `journeys_bench_test.dart`, with the boundaries onboarding needs kept
// apart instead of added up.
//
// ## What one run records
//
//  * **tap → acknowledgement, separately from completion.** After a tap
//    the probe pumps ONE frame at a time and notes the first frame the
//    acknowledgement is visible, the first frame the semantics tree
//    carries it, and the first frame the authoritative answer is on
//    screen. A provider that is held back moves only the last one.
//  * **entry → first usable authorized screen.** Frames until the
//    recipe's ready predicate holds, the routes actually rendered on the
//    way (sampled per frame: a redirect that settles before a frame is
//    drawn is not a flash anybody saw), and every separate loading
//    episode before arrival.
//  * **friction**, counted by what the scripted person does: active
//    decisions, fields typed, fields they had to type AGAIN because the
//    app lost them, Back corrections, required confirmations beside
//    duplicate unchanged ones, retries, and backend round trips.
//  * **waits** for a human, an e-mail or a provider, as counted
//    episodes. Their duration is not measured here and the record says
//    so — a wait is never folded into app time.
//
// ## Correctness before speed
//
// A run is a success only when its recipe ASSERTED the expected
// authorized screen or domain result and nothing on the way violated the
// recipe: lost input, a route shown twice, a result from another scope.
// A run that skipped the assertion is `incomplete`, never fast. There is
// no total score: every value is reported raw and on its own.
//
// Frames are pumps of 16 ms of FAKE time on a headless Dart VM. They are
// a count of work between two boundaries, not a frame rate.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'workload.dart' show BackendMeter;

/// A wait the person or the world owes the recipe; never app time.
enum WaitKind { human, email, provider }

/// How a run ended. Only [success] may be read as a measurement of a
/// completed task.
enum RecipeOutcome { success, refused, incomplete, incorrect }

/// Thrown by [RecipeProbe.arrive] when a screen never came: the run
/// already names why, and the recipe stops rather than tapping at a
/// screen that is not there.
class RecipeStopped implements Exception {
  const RecipeStopped(this.step);
  final String step;
  @override
  String toString() => 'recipe stopped at $step';
}

/// Frames from a tap to each of its three answers; null = never seen.
class Boundary {
  int? visible;
  int? semantic;
  int? done;
}

/// One run of one recipe: raw values, and the verdict that says whether
/// they describe a completed task.
class RecipeRun {
  RecipeRun(this.recipe, this.meter);

  final String recipe;
  final BackendMeter meter;

  /// Every location rendered, per frame, consecutive repeats collapsed.
  final trail = <String>[];

  /// The screens (paths) the person is MEANT to see. Anything else the
  /// router rendered for a frame is a flash.
  final stops = <String>{};

  /// Paths the recipe goes back to on purpose (a safe return).
  final allowedReturns = <String>{};

  /// Frames from each entry/arrival to its ready screen.
  final arrivals = <String, int>{};
  int loadingEpisodes = 0;
  int routeFlashes = 0;

  final boundaries = <String, Boundary>{};

  int decisions = 0;
  int fieldsEntered = 0;
  int userEdits = 0;
  int fieldsReentered = 0;
  int backCorrections = 0;
  int requiredConfirmations = 0;
  int duplicateConfirmations = 0;
  int retries = 0;
  final waits = <WaitKind, int>{};

  /// Element rebuilds (not first builds) over the whole run.
  int rebuilds = 0;
  int frames = 0;

  /// Where the recipe stopped because a screen never came, if it did.
  String? stoppedAt;

  final violations = <String>[];
  final missing = <String>[];
  bool? authorized;
  String? refusal;

  /// What the recipe left behind — location, domain rows — compared
  /// across motion settings, locales or samples. Values, not timings.
  final finalState = <String, String>{};

  RecipeOutcome get outcome {
    if (violations.isNotEmpty) return RecipeOutcome.incorrect;
    if (refusal != null) return RecipeOutcome.refused;
    if (authorized != true) return RecipeOutcome.incomplete;
    return RecipeOutcome.success;
  }

  String get why => switch (outcome) {
    RecipeOutcome.success => 'success',
    RecipeOutcome.refused => 'refused: $refusal',
    RecipeOutcome.incomplete =>
      authorized == null
          ? 'the recipe never asserted its authorized result'
          : 'not reached: ${missing.join('; ')}',
    RecipeOutcome.incorrect => violations.join('; '),
  };

  /// The raw values, by metric name. No sum, no weight, no score.
  Map<String, int> get metrics => {
    'success': outcome == RecipeOutcome.success ? 1 : 0,
    'trips': meter.trips,
    for (final c in meter.calls.entries) 'trips.${c.key}': c.value,
    'frames': frames,
    'rebuilds': rebuilds,
    'route_hops': trail.length,
    'route_flashes': routeFlashes,
    'loading_episodes': loadingEpisodes,
    for (final a in arrivals.entries) '${a.key}_frames': a.value,
    for (final b in boundaries.entries) ...{
      if (b.value.visible != null) '${b.key}_ack_frames': b.value.visible!,
      if (b.value.semantic != null)
        '${b.key}_ack_semantic_frames': b.value.semantic!,
      if (b.value.done != null) '${b.key}_done_frames': b.value.done!,
    },
    'decisions': decisions,
    'fields_entered': fieldsEntered,
    'user_edits': userEdits,
    'fields_reentered': fieldsReentered,
    'back_corrections': backCorrections,
    'required_confirmations': requiredConfirmations,
    'duplicate_confirmations': duplicateConfirmations,
    'retries': retries,
    for (final k in WaitKind.values) 'waits_${k.name}': waits[k] ?? 0,
  };
}

/// What moved between two runs of the SAME recipe on the same fixture.
/// Counts are deterministic here, so any difference is a change in the
/// work the recipe does — never jitter. Empty means identical.
Map<String, (int, int)> diffRuns(RecipeRun base, RecipeRun other) {
  final a = base.metrics, b = other.metrics;
  return {
    for (final k in {...a.keys, ...b.keys})
      if (a[k] != b[k]) k: (a[k] ?? -1, b[k] ?? -1),
  };
}

final _loading = find.byWidgetPredicate(
  (w) => w is CircularProgressIndicator || w is LinearProgressIndicator,
);

/// Drives one recipe frame by frame and fills its [RecipeRun].
class RecipeProbe {
  RecipeProbe(this.tester, this.run) {
    _semantics = tester.ensureSemantics();
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (_counting) run.rebuilds++;
    };
    _restore = () => debugOnRebuildDirtyWidget = previous;
    addTearDown(_release);
  }

  late final void Function() _restore;
  var _released = false;
  var _counting = true;

  /// Hands back the semantics handle and the rebuild hook. flutter_test
  /// checks for a live handle BEFORE tear-downs run, so [finish] calls
  /// this; the tear-down only covers a recipe that threw first.
  void _release() {
    if (_released) return;
    _released = true;
    _restore();
    _semantics.dispose();
  }

  final WidgetTester tester;
  final RecipeRun run;
  late final SemanticsHandle _semantics;
  final _typed = <String, String>{};
  final _confirmedSinceEdit = <String>{};

  static const frame = Duration(milliseconds: 16);

  /// The location the router has rendered, or null before it has one.
  String? get location {
    final routers = find
        .byWidgetPredicate(
          (w) => w is Router && w.routerDelegate is GoRouterDelegate,
        )
        .evaluate();
    if (routers.isEmpty) return null;
    final delegate =
        (routers.first.widget as Router).routerDelegate as GoRouterDelegate;
    if (delegate.currentConfiguration.isEmpty) return null;
    // The top of the stack, pushed routes included — what is on screen.
    final uri = delegate.state.uri.toString();
    return uri.isEmpty ? null : uri;
  }

  GoRouter get router =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  void _sample() {
    final at = location;
    if (at != null && (run.trail.isEmpty || run.trail.last != at)) {
      run.trail.add(at);
    }
  }

  Future<void> pumpFrame() async {
    await tester.pump(frame);
    run.frames++;
    _sample();
  }

  /// Pumps until nothing is scheduled, like `pumpAndSettle`, sampling
  /// every frame.
  Future<void> settle({int max = 3000}) async {
    var n = 0;
    do {
      await pumpFrame();
      n++;
    } while (tester.binding.hasScheduledFrame && n < max);
  }

  /// Entry or arrival: frames until [ready], counting every separate
  /// loading episode on the way. Returns the frames it took. Never getting
  /// there is a violation, not a slow arrival, and stops the recipe.
  Future<int> arrive(
    String name,
    bool Function() ready, {
    int max = 600,
  }) async {
    var n = 0, wasLoading = false;
    while (!ready() && n < max) {
      await pumpFrame();
      n++;
      final loading = _loading.evaluate().isNotEmpty && !ready();
      if (loading && !wasLoading) run.loadingEpisodes++;
      wasLoading = loading;
    }
    await settle();
    if (!ready()) {
      run.violations.add('$name never reached its ready screen');
      throw RecipeStopped(name);
    }
    run.arrivals[name] = n;
    return n;
  }

  /// Mounts [app] and measures the entry to [ready]. Whatever was
  /// mounted before is taken down first: `pumpWidget` of a widget of the
  /// same type UPDATES the old tree, so without this a second sample (or
  /// a restart) would inherit the first one's state.
  Future<void> enter(Widget app, bool Function() ready) async {
    _counting = false;
    await tester.pumpWidget(const SizedBox.shrink());
    _counting = true;
    await tester.pumpWidget(app);
    _sample();
    await arrive('entry', ready);
  }

  // The four taps below do NOT settle: the caller says what comes next —
  // `arrive` when the tap navigates, so the frames from the tap to the
  // screen it opens are counted from the tap, or `settle` when it does
  // not.

  /// A deliberate choice the person makes.
  Future<void> choose(Finder target) async {
    run.decisions++;
    await _tap(target);
  }

  /// A confirmation. [required] ones (consent, a security step) are not
  /// friction; the same unchanged confirmation twice is.
  Future<void> confirm(
    Finder target, {
    required String what,
    bool required = false,
  }) async {
    if (required) run.requiredConfirmations++;
    if (!_confirmedSinceEdit.add(what)) run.duplicateConfirmations++;
    run.decisions++;
    await _tap(target);
  }

  Future<void> back(Finder target) async {
    run.backCorrections++;
    await _tap(target);
  }

  Future<void> retry(Finder target) async {
    run.retries++;
    await _tap(target);
  }

  void wait(WaitKind kind) =>
      run.waits.update(kind, (n) => n + 1, ifAbsent: () => 1);

  /// The person changes their own earlier answer: a requested edit,
  /// counted apart from re-entry the app forced on them.
  Future<void> edit(Finder field, String text, {required String name}) async {
    run.userEdits++;
    _typed[name] = text;
    _confirmedSinceEdit.clear();
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await pumpFrame();
  }

  /// Types [text] into [field] once, remembered as [name].
  Future<void> type(Finder field, String text, {required String name}) async {
    run.fieldsEntered++;
    _typed[name] = text;
    _confirmedSinceEdit.clear();
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await pumpFrame();
  }

  /// The person comes back to [field]: what they typed must still be
  /// there. If it is not, they type it again — counted — and the run is
  /// incorrect, because lost input is not a slower success.
  Future<void> expectKept(Finder field, {required String name}) async {
    final want = _typed[name]!;
    final have = _textOf(field);
    if (have == want) return;
    run.fieldsReentered++;
    run.violations.add('lost input: $name ("$have" instead of "$want")');
    await tester.enterText(field, want);
    await pumpFrame();
  }

  String? _textOf(Finder field) {
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
      matchRoot: true,
    );
    if (editable.evaluate().isEmpty) return null;
    return tester.widget<EditableText>(editable.first).controller.text;
  }

  /// Taps [target] and pumps single frames until [done] or [max],
  /// noting the first frame of each answer.
  Future<Boundary> act(
    String name,
    Finder target, {
    required bool Function() visible,
    required bool Function() semantic,
    required bool Function() done,
    int max = 240,
    bool decision = true,
    void Function(int frame)? onFrame,
  }) async {
    if (decision) run.decisions++;
    final b = run.boundaries[name] = Boundary();
    await _tap(target);
    for (var n = 1; n <= max; n++) {
      onFrame?.call(n);
      await pumpFrame();
      if (b.visible == null && (visible() || done())) b.visible = n;
      if (b.semantic == null && (semantic() || done())) b.semantic = n;
      if (done()) {
        b.done = n;
        break;
      }
    }
    return b;
  }

  Future<void> _tap(Finder target) async {
    await tester.ensureVisible(target);
    await pumpFrame();
    await tester.tap(target);
  }

  /// The recipe's authorized screen or domain result. Must be called
  /// before a run can be a success; a false answer leaves the run
  /// incomplete and names [what].
  void authorize(String what, bool holds) {
    run.authorized = (run.authorized ?? true) && holds;
    if (!holds) run.missing.add(what);
  }

  /// A wrong result on screen — another scope's answer, a second effect.
  /// Present, it makes the run incorrect however fast it was.
  void forbid(String what, bool happened) {
    if (happened) run.violations.add(what);
  }

  /// The domain said no. A refused task is reported as refused.
  void refused(String why) => run.refusal = why;

  /// Closes the run: a path rendered that is not one of the recipe's
  /// stops is a flash (counted); a stop seen again after it was left,
  /// other than a declared return, is a detour (a violation — the person
  /// was sent somewhere they had already been).
  void finish() {
    run.finalState['location'] = location ?? '';
    _release();
    final seen = <String>{};
    String? previous;
    for (final l in run.trail) {
      final path = Uri.parse(l).path;
      if (path == previous) continue;
      previous = path;
      if (!run.stops.contains(path)) {
        run.routeFlashes++;
        continue;
      }
      if (!seen.add(path) && !run.allowedReturns.contains(path)) {
        run.violations.add('duplicate route detour: $path');
      }
    }
  }

  // ── predicates the recipes share ────────────────────────────────────

  bool shows(Finder f) => f.evaluate().isNotEmpty;

  /// A finder for the element [f] matches NOW — a button whose label is
  /// replaced by a spinner while busy stays the same element, so the
  /// acknowledgement can be read off the thing that was tapped.
  Finder pin(Finder f) {
    final element = f.evaluate().single;
    return find.byElementPredicate((e) => identical(e, element));
  }

  /// The action's semantics node says it is not actionable now — what a
  /// screen reader announces for a button that took the tap.
  bool semanticallyDisabled(Finder f) {
    if (f.evaluate().isEmpty) return false;
    return tester
            .getSemantics(f)
            .getSemanticsData()
            .flagsCollection
            .isEnabled ==
        Tristate.isFalse;
  }

  /// [f] is on screen AND the semantics node that carries it has words —
  /// what an assistive technology would read out.
  bool readable(Finder f) {
    if (f.evaluate().isEmpty) return false;
    return tester.getSemantics(f.first).getSemanticsData().label.isNotEmpty;
  }

  /// A label in the semantics tree, not just a widget in the element one.
  bool announces(Pattern label) =>
      find.bySemanticsLabel(label).evaluate().isNotEmpty;

  bool buttonBusy(Finder f) =>
      f.evaluate().isNotEmpty &&
      (find.descendant(of: f, matching: _loading).evaluate().isNotEmpty ||
          _disabled(f));

  bool _disabled(Finder f) {
    final w = tester.widget(f);
    return w is ButtonStyleButton && w.onPressed == null;
  }
}

/// Resets the view the recipe sized, the Flutter way.
void sizeView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
