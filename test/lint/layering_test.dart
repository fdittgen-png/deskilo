// SPDX-License-Identifier: AGPL-3.0-or-later
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

import '../../tool/code_health_budgets.dart';
import '../../tool/layering/analysis.dart' as layering;

import 'lint_sources.dart';

/// Every ordered feature→feature import pair that exists today.
///
/// RATCHET: removing a pair is a normal pull request; adding one means
/// either using an existing seam instead, or adding the pair HERE with a
/// one-line justification in the PR description.
///
/// #1233 — the counts ARE tracked now, in `budgets.pairBudget` (see below). Tracking
/// only the pair names was the hole: all 54 were live, and behind them
/// sat 656 import statements. A pair already on the list could grow
/// without limit, and `money -> workspace` had reached 111, which is not
/// a dependency but a merger. The counts may only fall.

/// How many widget FILES in each feature still reach a repository
/// directly (#1234). 66 of them, and this is the ratchet that empties
/// them.
///
/// A count and not a list of names, for the same reason the pair budget
/// counts imports rather than listing pairs: presence tells you nothing
/// about progress. `reservations` went 5 → 4 when
/// `application/book_seat.dart` took the booking decision out of a
/// 740-line widget method, and that is exactly the kind of step this has
/// to be able to see.
///
/// Every number may only go DOWN. A feature that reaches zero leaves
/// `budgets.repositoryInWidgets` of docs/design/CODE_HEALTH_BASELINE.json
/// (written by `dart run tool/code_health.dart --baseline`, #2598), after
/// which any widget in it touching a repository fails.

const Set<String> _knownPairs = {
  // #1865 — the task recorder: the help screen offers "Record this
  // task"; the Reserve hub, the booking sheet flow and the reservation
  // sheet call the recorder's seam; the booking adapter reads the
  // booking command's outcome type; the recorder reads the workspace's
  // flag and active workspace for its scope.
  'reservations -> task_recorder',
  'task_recorder -> reservations',
  'task_recorder -> workspace',
  // #1884 — the feature switch calls the recorder's seam.
  'workspace -> task_recorder',
  // #2142 — Me → Account offers "Record a task" (the recorder's route).
  'me -> task_recorder',
  // #1881 B — the calendar and its decisions call the recorder's seam
  // and its calendar adapter; the recorder names a calendar kind the way
  // the calendar does.
  'calendar -> task_recorder',
  'events -> task_recorder',
  'task_recorder -> calendar',
  // #1884 B — the recorder names an event type's validation rule the
  // way the validation screen does.
  'task_recorder -> events',
  // #1823 — the Me layer is the account's home: it shows the account
  // messenger and discovery (directory), my spaces and memberships
  // (workspace), my photo and account rows (profile), and signs out (auth).
  'me -> auth', 'me -> directory', 'me -> profile', 'me -> workspace',
  // #1835 — Me › Home lists the account's guest visits: a relationship of
  // the account, read beside its memberships and never confused with one.
  'me -> visits',
  // ADR 0035 — Me › Home shows what I owe across my spaces and opens Me ›
  // Finances, which is the money feature's own screen.
  'me -> money',
  // #2313 — each of my spaces on Me › Home shows what waits there: the
  // space I am in counts the decisions waiting for me, as the app icon does.
  'me -> events',
  // #1835 — a visit is read for the signed-in account only, so the visits
  // providers ask who that is (auth), as every account read does.
  'visits -> auth',
  // #1791: account-bound portal, workspace publication/employment and profile entry.
  'workspace -> directory', 'directory -> auth', 'directory -> workspace',
  'directory -> reservations', // 2026-10-04 #2185: a workspace card carries the feedback bar
  // #1824 — Me › Messages IS the unified inbox, which lives with the
  // account messenger it grew from ('me -> directory', above).
  'profile -> directory', 'money -> auth',
  // #1642 — Help discards local support previews when identity/workspace changes.
  'help -> auth',
  'help -> workspace',
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
  // #2477 — the platform owner's tax reference editor opens from the
  // platform section of the profile list.
  'profile -> money',
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
  // #1615 — the consent screen lets a person the database has not
  // approved ask for approval: auth owns the identity binding and its
  // eligibility request (connect_assistant's provider).
  'mcp -> auth',
  // #1626 — the policy screen edits the CURRENT workspace and its
  // settings entry reads the workspace's mcpAccess flag and ownership.
  'mcp -> workspace',
  // #1626/#1627/#1628 — settings shows the assistant entries (one widget).
  'profile -> mcp',
  'workspace -> events',
  'workspace -> money',
  'workspace -> plan',
  // #395: the data export's Users tab reads profile details (country,
  // VAT id, address) through the pure profile domain model.
  'workspace -> profile',
  'workspace -> reservations',
};


/// The number of imports behind each committed pair is a ceiling, never a
/// target (#1233): `budgets.pairBudget` in
/// docs/design/CODE_HEALTH_BASELINE.json, written by
/// `dart run tool/code_health.dart --baseline` (#2598), which lowers it and
/// refuses a raise.

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
/// `serverErrorMessage` / `serverErrorCode` / `isAuthError` and delete
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
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart',
  'lib/features/reservations/domain/booking_error_text.dart',
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart',
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart',
};


/// The feature a repo-relative path belongs to, or null.


void main() {
  test('presentation/ never imports data/ (AGENT_RULES layering)', () {
    final violations = <String>[];
    for (final file in _featureFiles()) {
      if (!file.path.contains('/presentation/')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = layering.importRe.firstMatch(lines[i]);
        if (m == null) continue;
        final imp = m.group(1)!;
        final resolved = imp.startsWith('package:deskilo/')
            ? imp.replaceFirst('package:deskilo/', 'lib/')
            : layering.resolveRelative(
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
    final failures = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'repositoryInWidgets');
    expect(
      failures,
      isEmpty,
      reason: 'a widget started calling a repository directly, or a budget '
          'can fall:\n${failures.join('\n')}\n\n'
          'Put the DECISION in lib/features/<feature>/application/ and '
          'let the widget say what the member asked for. ADR 0024, and '
          'lib/features/reservations/application/book_seat.dart is the '
          'worked example.',
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
            'serverErrorMessage / serverErrorCode / isAuthError from '
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
    for (final file in _featureFiles()) {
      final src = layering.featureOf(file.path)!;
      for (final m in layering.importRe.allMatches(file.readAsStringSync())) {
        final imp = m.group(1)!;
        String? target;
        if (imp.startsWith('package:deskilo/features/')) {
          target = imp.split('/')[2];
        } else {
          final resolved = layering.resolveRelative(
              file.path.substring(0, file.path.lastIndexOf('/')), imp);
          if (resolved != null) target = layering.featureOf(resolved);
        }
        if (target != null && target != src) {
          live.add('$src -> $target');
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
    // name-only ratchet could never see (#2598: budgets.pairBudget).
    final volume = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'pairBudget');
    expect(volume, isEmpty,
        reason: 'coupling moved behind a committed pair. Route growth '
            'through a seam; a fall is written by the command:\n'
            '${volume.join('\n')}');
  });
}
