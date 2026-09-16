// SPDX-License-Identifier: 0BSD
//
// Architecture lint: the feature-first layering rules, machine-enforced.
//
// CONTRIBUTING.md and AGENT_RULES.md have stated since day one that
// `presentation/` never imports `data/` and that `domain/` is pure Dart.
// Until now both were conventions — honoured by review, checked by
// nothing. The first sweep found one violation (`qr_png.dart` rendered a
// PNG through Flutter's Canvas from inside `domain/`; it moved to
// `presentation/`), which is the argument in one line: conventions decay,
// tests do not.
//
// The third rule is a ratchet on COUPLING: the set of cross-feature
// import pairs (feature A importing from feature B) is committed below
// and may only ever shrink. A new pair is not forbidden — shared
// building blocks like PlanCanvas are the documented pattern — but it
// must be a conscious act recorded in this file, not a quiet
// consequence of reaching for something two directories over.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Every ordered feature→feature import pair that exists today.
///
/// RATCHET: removing a pair is a normal pull request; adding one means
/// either using an existing seam instead, or adding the pair HERE with a
/// one-line justification in the PR description.
///
/// #1233 — the counts ARE tracked now, in [_pairBudget] below. Tracking
/// only the pair names was the hole: all 54 were live, and behind them
/// sat 656 import statements. A pair already on the list could grow
/// without limit, and `money -> workspace` had reached 111, which is not
/// a dependency but a merger. The counts may only fall.
/// A widget reaching a repository: `ref.read(xRepositoryProvider)` or
/// `ref.watch(...)`, which is the exact shape #1234 counted 125 of.
final RegExp _repositoryUse =
    RegExp(r'ref\.(read|watch)\(\s*[a-zA-Z]+RepositoryProvider');

/// How many widget FILES in each feature still reach a repository
/// directly (#1234). 66 of them, and this is the ratchet that empties
/// them.
///
/// A count and not a list of names, for the same reason `_pairBudget`
/// counts imports rather than listing pairs: presence tells you nothing
/// about progress. `reservations` went 5 → 4 when
/// `application/book_seat.dart` took the booking decision out of a
/// 740-line widget method, and that is exactly the kind of step this has
/// to be able to see.
///
/// Every number may only go DOWN. A feature that reaches zero is deleted
/// from the map, after which any widget in it touching a repository
/// fails.
const Map<String, int> _repositoryInWidgets = {
  'money': 25,
  'workspace': 20,
  'auth': 4,
  // Still 4 after #1234: `space_act_sheet.dart` moved its DECISION to
  // `application/act_on_space.dart` but still resolves the repository
  // from a provider to hand it over — exactly as
  // `reserve_seat_actions.dart` does for `bookSeat`. This ratchet
  // counts provider reads, and a command's caller still makes one.
  'reservations': 4,
  'editor': 3,
  'profile': 3,
  'members': 2,
  'plan': 2,
  'calendar': 1,
  'events': 1,
  'kiosk': 1,
};

const Set<String> _knownPairs = {
  // #718 — the calendar hub opens invoices and the Money month from a
  // dated row: money's own sheet and its focus controller, not a copy.
  'calendar -> money',
  'money -> calendar',
  'calendar -> events',
  'calendar -> plan',
  'calendar -> reservations',
  'calendar -> workspace',
  'editor -> plan',
  'editor -> workspace',
  'events -> money',
  // #704 — a member's profile shows where they stand: the account, the
  // invoices, the payments. The figures come from money's own providers
  // and its shared AccountCard, so the profile cannot compute a position
  // that disagrees with the Money tab.
  'members -> money',
  // #719 — Settings → Privacy & data exercises the GDPR rights through the
  // calendar feature's repository (the RPCs live with the hub they serve)
  // and opens its access sheet: one implementation of "who can see my
  // data", not a second.
  'profile -> calendar',
  'events -> plan',
  'events -> reservations',
  'events -> workspace',
  'kiosk -> events',
  'kiosk -> members',
  'kiosk -> plan',
  'kiosk -> reservations',
  'kiosk -> workspace',
  'members -> plan',
  'members -> profile',
  // #616: the kiosk receipt reuses the shared MemberAvatar widget —
  // the same avatar building block the directory uses.
  'kiosk -> profile',
  // #620: the Reserve hub map resolves occupant photos through the
  // profile providers — the same building block as plan and kiosk.
  'reservations -> profile',
  'members -> reservations',
  'members -> workspace',
  'money -> events',
  'money -> members',
  // #496 — the agreement/reminder letters resolve the reader's language
  // from their profile.
  'money -> profile',
  'workspace -> members',
  // #494 — the financial agreement prices whole-space bookings and
  // accessory supplements straight from the plan catalog.
  'money -> plan',
  'money -> reservations',
  'money -> workspace',
  'plan -> events',
  'plan -> members',
  'plan -> profile',
  'plan -> reservations',
  'plan -> workspace',
  'profile -> auth',
  'profile -> members',
  // #586 — Settings surfaces the member's default reservation period.
  'profile -> reservations',
  'profile -> workspace',
  'reservations -> calendar',
  'reservations -> events',
  'reservations -> members',
  'reservations -> money',
  // #537 (2026-08-11): accessory supplements are PRICED — the plan's
  // accessories screen names the workspace default VAT rate on its
  // rows, via money's vat_price_label + vatRatesProvider.
  'plan -> money',
  'reservations -> plan',
  'reservations -> workspace',
  'workspace -> auth',
  'workspace -> events',
  'workspace -> money',
  'workspace -> plan',
  // #395: the data export's Users tab reads profile details (country,
  // VAT id, address) through the pure profile domain model.
  'workspace -> profile',
  'workspace -> reservations',
};

final _importRe = RegExp("import '([^']+)'");

/// The number of imports behind each committed pair — a ceiling, never
/// a target. It may only go DOWN: a refactor that removes coupling
/// lowers its line, and a change that adds an import to an existing pair
/// has to say so here.
const Map<String, int> _pairBudget = {
  'calendar -> events': 3,
  'calendar -> money': 6,
  'calendar -> plan': 6,
  // 2026-09-14 #1269 7→8: the day view reads `browsedLevelProvider`.
  // The browsed level is ONE value the plan, the day and the week
  // share — three private copies is what made it snap back to the
  // first floor on every view switch — and it belongs to the feature
  // that owns booking, not to the calendar.
  'calendar -> reservations': 8,
  'calendar -> workspace': 15,
  'editor -> plan': 20,
  'editor -> workspace': 6,
  'events -> money': 5,
  'events -> plan': 1,
  'events -> reservations': 3,
  'events -> workspace': 18,
  'kiosk -> events': 1,
  'kiosk -> members': 1,
  'kiosk -> plan': 7,
  'kiosk -> profile': 2,
  // 9→10 (2026-09-16): #1234 — `SpaceAction`/`SpaceActChoice` moved
  // from `presentation/widgets/space_act_form.dart` to
  // `domain/space_act.dart` so the application layer could name them
  // without importing a widget file. kiosk_act_sheet needs both (it
  // renders the form AND names the choice); kiosk_screen needed only
  // the types, and its now-dead form import was removed — so this is
  // +1, not +2.
  'kiosk -> reservations': 10,
  'kiosk -> workspace': 7,
  'members -> money': 8,
  'members -> plan': 3,
  'members -> profile': 9,
  'members -> reservations': 14,
  'members -> workspace': 34,
  'money -> calendar': 1,
  'money -> events': 30,
  'money -> members': 2,
  'money -> plan': 14,
  'money -> profile': 4,
  'money -> reservations': 13,
  // 2026-09-15 #1310 S0 112→113: the invoice register asks for the
  // exportData permission before offering the accounting export.
  'money -> workspace': 113,
  'plan -> events': 1,
  'plan -> members': 1,
  'plan -> money': 4,
  'plan -> profile': 2,
  'plan -> reservations': 9,
  // 2026-09-15 #1273 10→11: floor_plan_providers reads the
  // singleRoomLevelNames flag once for every map surface.
  'plan -> workspace': 11,
  'profile -> auth': 6,
  'profile -> calendar': 2,
  'profile -> members': 1,
  'profile -> reservations': 5,
  // 2026-09-15 #1310 S0 30→31: the developer reservation dump asks for
  // the exportData permission before exporting anyone but the exporter.
  //
  // 2026-09-16 #1307 31→35, and this one is a DELIBERATE trade, not
  // drift. settings_screen.dart sat at exactly its length cap, so
  // Settings could not be reorganized by ownership until something
  // left; the Advanced section moved to widgets/. Splitting one file
  // into two re-states the imports BOTH halves need —
  // workspace_feature, workspace_permission and workspace_providers are
  // each now imported twice inside profile/, because the screen still
  // uses them for the personal and preferences sections.
  //
  // The fourth is application/set_workspace_dev_mode.dart. Keeping that
  // decision in the widget would have cost one import less and broken
  // `profile: 4 > 3` instead — a widget in profile/ reaching
  // workspace/'s repository. ADR 0024 is the stronger rule, so the
  // layer violation is fixed and the import ceiling pays for it.
  'profile -> workspace': 35,
  'reservations -> calendar': 1,
  'reservations -> events': 5,
  'reservations -> members': 2,
  'reservations -> money': 1,
  // 2026-09-15 #1273 62→63: the seat list names a level's only room by
  // the level through floor_plan_providers, like the day and week views.
  'reservations -> plan': 63,
  'reservations -> profile': 1,
  // 48→50 (2026-09-16): #1234 — `application/act_on_space.dart` and
  // `domain/space_act.dart` both need `BookingGranularity`: the
  // check-in window rule widens with the grid step, so the decision
  // cannot be made without it. Two imports, both load-bearing.
  'reservations -> workspace': 50,
  'workspace -> auth': 3,
  'workspace -> events': 11,
  'workspace -> members': 4,
  'workspace -> money': 34,
  'workspace -> plan': 25,
  'workspace -> profile': 10,
  'workspace -> reservations': 17,
};

Iterable<File> _featureFiles() => handWrittenDartFiles('lib/features');

/// #1233 — the layering rules used to scan `lib/features` only, so
/// `lib/core` and `lib/app` — a fifth of the hand-written source — sat
/// outside every one of them. A rule that half the tree is exempt from
/// is a convention wearing a test's clothes.
Iterable<File> _allSourceFiles() =>
    handWrittenDartFilesIn(['lib/features', 'lib/core', 'lib/app']);

/// The files that still name a backend type outside `data/`.
///
/// RATCHET, and it may only shrink. Each of these needs the server's own
/// message out of a `PostgrestException` or an `AuthException` in order
/// to map it to something a person can read — which is an infrastructure
/// detail with a one-line answer, and the answer now lives in
/// `lib/core/data/server_error.dart`. Route a file through
/// `serverErrorMessage` / `isDatabaseError` / `isAuthError` and delete
/// its line here.
/// Where the backend legitimately lives: the client itself, the realtime
/// subscription, the push endpoint registry and the boot sequence that
/// starts them. Everything else talks to the server through a repository.
const Set<String> _infrastructureDirs = {
  'lib/core/backend/',
  'lib/core/realtime/',
  'lib/core/push/',
  'lib/app/app_initializer.dart',
};

const Set<String> _backendTypeOutsideData = {
  'lib/core/trace/act_trace.dart',
  'lib/features/auth/presentation/screens/auth_screen.dart',
  'lib/features/auth/presentation/screens/linked_accounts_screen.dart',
  'lib/features/editor/presentation/widgets/seat_properties_sheet.dart',
  'lib/features/events/presentation/screens/events_screen.dart',
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart',
  'lib/features/reservations/domain/booking_error_text.dart',
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart',
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart',
};

/// Resolves [import] against [fromDir] to a repo-relative path, or null
/// for package/dart imports. Hand-rolled so this test needs no
/// dependency beyond dart:io.
String? _resolveRelative(String fromDir, String import) {
  if (!import.startsWith('.')) return null;
  final parts = <String>[...fromDir.split('/')];
  for (final seg in import.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// The feature a repo-relative path belongs to, or null.
/// Source with `//` comments removed.
///
/// A lint that scans raw text reports the comment EXPLAINING the rule as
/// a violation of it — which this repository has learned twice now. The
/// paragraph above this test contains `ref.read(xRepositoryProvider)`
/// and must not count.
String _withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('//');
      return at < 0 ? line : line.substring(0, at);
    })
    .join('\n');

String? _featureOf(String path) {
  final parts = path.split('/');
  if (parts.length > 2 && parts[0] == 'lib' && parts[1] == 'features') {
    return parts[2];
  }
  return null;
}

void main() {
  test('presentation/ never imports data/ (AGENT_RULES layering)', () {
    final violations = <String>[];
    for (final file in _featureFiles()) {
      if (!file.path.contains('/presentation/')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = _importRe.firstMatch(lines[i]);
        if (m == null) continue;
        final imp = m.group(1)!;
        final resolved = imp.startsWith('package:deskilo/')
            ? imp.replaceFirst('package:deskilo/', 'lib/')
            : _resolveRelative(
                file.path.substring(0, file.path.lastIndexOf('/')), imp);
        if (resolved != null && resolved.contains('/data/')) {
          violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'presentation/ imports data/ — go through providers/:\n'
          '${violations.join('\n')}',
    );
  });

  // #1234 — the application layer, one context at a time.
  //
  // `presentation/` says what the member ASKED for, `application/`
  // decides which write that is, `data/` performs it. 125 widgets reach
  // a repository directly today, and moving them all in one branch is
  // how a refactor this size goes wrong — so this is a SHRINKING
  // allow-list, feature by feature, the same shape as
  // `_backendTypeOutsideData`.
  //
  // A feature NOT on the list may not touch a repository from
  // presentation at all. `reservations` is the first one off it: ADR
  // 0024 and `application/book_seat.dart` are the proof of shape, and
  // the remaining entries below are what is left to move there.
  test('presentation/ reaches repositories only where the application '
      'layer has not arrived yet (#1234)', () {
    final offenders = <String, List<String>>{};
    for (final file in _featureFiles()) {
      if (!file.path.contains('/presentation/')) continue;
      final feature = _featureOf(file.path);
      if (feature == null) continue;
      final text = _withoutComments(file.readAsStringSync());
      if (!_repositoryUse.hasMatch(text)) continue;
      (offenders[feature] ??= []).add(file.path);
    }

    final grew = <String>[];
    final shrank = <String>[];
    for (final entry in offenders.entries) {
      final budget = _repositoryInWidgets[entry.key];
      if (budget == null) {
        grew.add('${entry.key}: ${entry.value.length} files, and this '
            'feature is supposed to be finished:\n    '
            '${entry.value.join('\n    ')}');
      } else if (entry.value.length > budget) {
        grew.add('${entry.key}: ${entry.value.length} > $budget');
      } else if (entry.value.length < budget) {
        shrank.add('${entry.key}: ${entry.value.length} (budget $budget)');
      }
    }

    expect(
      grew,
      isEmpty,
      reason: 'a widget started calling a repository directly:\n'
          '${grew.join('\n')}\n\n'
          'Put the DECISION in lib/features/<feature>/application/ and '
          'let the widget say what the member asked for. ADR 0024, and '
          'lib/features/reservations/application/book_seat.dart is the '
          'worked example.',
    );
    expect(
      shrank,
      isEmpty,
      reason: 'good — lower these in _repositoryInWidgets in the same '
          'commit, so the next person inherits the ground you took:\n'
          '${shrank.join('\n')}',
    );
  });

  // #1234 — `application/` is covered here too, and was not.
  //
  // The rule ADR 0024 states is that `application/` decides WHICH WRITE a
  // request is and nothing else: no BuildContext, no rendering. Three
  // commands honoured that, and nothing enforced it — this test filtered
  // on `/domain/` alone. Writing `act_on_space.dart` found the hole the
  // obvious way: the choice types it needed were declared at the top of
  // `space_act_form.dart`, a widget file importing material.dart, so the
  // command would have pulled Material into the application layer and the
  // suite would have stayed green. The types moved to
  // `domain/space_act.dart`; this stops the next one.
  test('domain/ and application/ are pure Dart — no Flutter, no dart:ui',
      () {
    final violations = <String>[];
    for (final file in _featureFiles()) {
      if (!file.path.contains('/domain/') &&
          !file.path.contains('/application/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains("import 'package:flutter/") ||
            line.contains("import 'dart:ui")) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'domain/ and application/ must stay pure Dart (AGENT_RULES, '
          'ADR 0024) — anything that paints, renders or touches a '
          'BuildContext belongs in presentation/:\n'
          '${violations.join('\n')}',
    );
  });

  // #1233 — `domain/` was checked for Flutter and `dart:ui` and nothing
  // else, so the backend could sit inside the one directory the rules
  // call pure Dart and the CLI imports. `presentation/` was not checked
  // at all, and seven screens named Postgrest and Auth exceptions.
  test('the backend is named only in data/ — everywhere else goes '
      'through core/data/server_error.dart (ratchet)', () {
    final violations = <String>[];
    for (final file in _allSourceFiles()) {
      final path = file.path;
      // `data/` is where a backend type belongs, and the seam itself is
      // the one file in `core/` whose whole job is to know one.
      if (path.contains('/data/')) continue;
      // The infrastructure directories: these ARE the backend adapter,
      // and each is named rather than pattern-matched so that adding a
      // fourth is a decision somebody writes down.
      if (_infrastructureDirs.any(path.startsWith)) continue;
      // `providers/` is the composition root: it hands the live client
      // to the repositories, which is wiring rather than a leak. What
      // it must not do is name an exception type, and that is what the
      // check below looks for.
      if (path.contains('/providers/') &&
          !file.readAsStringSync().contains('Exception')) {
        continue;
      }
      if (!file.readAsStringSync().contains("package:supabase_flutter/")) {
        continue;
      }
      if (_backendTypeOutsideData.contains(path)) continue;
      violations.add(path);
    }
    expect(violations, isEmpty,
        reason: 'these name a Supabase type outside data/. Use '
            'serverErrorMessage / isDatabaseError / isAuthError from '
            'lib/core/data/server_error.dart:\n${violations.join('\n')}');

    final gone = _backendTypeOutsideData
        .where((p) => !File(p).existsSync() ||
            !File(p).readAsStringSync().contains('package:supabase_flutter/'))
        .toList();
    expect(gone, isEmpty,
        reason: 'these no longer name a backend type — delete them from '
            '_backendTypeOutsideData so the ratchet keeps its meaning:\n'
            '${gone.join('\n')}');
  });

  test('cross-feature import pairs stay inside the committed set (ratchet)',
      () {
    final live = <String>{};
    final counts = <String, int>{};
    for (final file in _featureFiles()) {
      final src = _featureOf(file.path)!;
      for (final m in _importRe.allMatches(file.readAsStringSync())) {
        final imp = m.group(1)!;
        String? target;
        if (imp.startsWith('package:deskilo/features/')) {
          target = imp.split('/')[2];
        } else {
          final resolved = _resolveRelative(
              file.path.substring(0, file.path.lastIndexOf('/')), imp);
          if (resolved != null) target = _featureOf(resolved);
        }
        if (target != null && target != src) {
          live.add('$src -> $target');
          counts.update('$src -> $target', (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }

    final added = live.difference(_knownPairs);
    expect(
      added,
      isEmpty,
      reason: 'NEW cross-feature coupling: ${added.join(', ')}.\n'
          'Either route it through an existing seam (a shared building '
          'block in core/ or the owning feature\'s providers), or add the '
          'pair to _knownPairs with a one-line justification in the PR '
          'description. Coupling is allowed; unnoticed coupling is not.',
    );

    final gone = _knownPairs.difference(live);
    expect(
      gone,
      isEmpty,
      reason: 'These pairs no longer exist — RATCHET them out by deleting '
          'from _knownPairs (baselines may only shrink, and a stale entry '
          'would let the coupling quietly return): ${gone.join(', ')}',
    );

    // #1233 — and the VOLUME behind each pair, which is the half the
    // name-only ratchet could never see.
    final grew = <String>[];
    final shrank = <String>[];
    for (final entry in counts.entries) {
      final budget = _pairBudget[entry.key];
      if (budget == null) continue; // a new pair; `added` already failed
      if (entry.value > budget) {
        grew.add('${entry.key}: ${entry.value} > $budget');
      } else if (entry.value < budget) {
        shrank.add('${entry.key}: ${entry.value} (budget $budget)');
      }
    }
    expect(grew, isEmpty,
        reason: 'coupling GREW behind an already-committed pair. Route it '
            'through a seam, or raise the line in _pairBudget and say why '
            'in the PR:\n${grew.join('\n')}');
    expect(shrank, isEmpty,
        reason: 'coupling shrank — lower these in _pairBudget in the same '
            'commit, or the ceiling stops meaning anything:\n'
            '${shrank.join('\n')}');
  });
}
