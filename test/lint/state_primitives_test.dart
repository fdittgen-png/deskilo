// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S1 — an empty list must never look like a failed one.
//
// The app already has the primitives: `LoadingView`, `EmptyState`,
// `InlineBanner`, `AppSnack` and `runGuarded`. Across lib/ they are used
// 48, 21 and 16 times respectively. What undercuts them is the raw
// `CircularProgressIndicator` dropped straight into a screen: it says
// "something is happening" and nothing else — not what is loading, not
// whether existing content is still valid, not what to do if it never
// finishes.
//
// Measured on master 2026-09-16: **15** raw spinners, in 15 different
// files, one each. (#1305's brief says 14; the code says 15. The code
// is authoritative and the difference is why this is a measurement
// rather than a transcription.)
//
// ## Why a ratchet and not a ban
//
// Some of the 15 are legitimate: a 24×24 spinner inside a button that
// has already been pressed is not a screen state, it is a control
// state, and `LoadingView` would be wrong there. Sorting the honest
// ones from the lazy ones is a per-file judgement nobody has made yet.
//
// So this counts them and refuses to let the number grow. A file that
// keeps a spinner keeps its entry; a file that adopts a primitive drops
// out of the baseline in the same commit — which is the mechanism, the
// same one `no_hardcoded_strings_test` and `_repositoryInWidgets` use.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Files still building a raw spinner → how many. Ratchet DOWN only.
///
/// Every entry is a place where somebody will eventually ask "loading
/// what, and what if it never arrives?". Deleting a line here is the
/// point of the file.
const Map<String, int> _baseline = {
  'lib/features/auth/presentation/screens/auth_screen.dart': 1,
  'lib/features/auth/presentation/screens/linked_accounts_screen.dart': 1,
  'lib/features/auth/presentation/widgets/badge_sign_in_sheet.dart': 1,
  'lib/features/money/presentation/screens/report_editor_screen.dart': 1,
  'lib/features/money/presentation/widgets/invoice_form_sheet.dart': 1,
  'lib/features/money/presentation/widgets/usage_face.dart': 1,
  'lib/features/profile/presentation/widgets/backend_candidate_form.dart': 1, // #1651 the Test button's in-flight spinner moved here with the form
  'lib/features/profile/presentation/screens/developer_screen.dart': 1,
  'lib/features/profile/presentation/screens/personal_info_screen.dart': 1,
  'lib/features/profile/presentation/widgets/workspace_owners_sheet.dart': 1,
  'lib/features/workspace/presentation/screens/workspace_code_screen.dart': 1,
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': 1,
  'lib/features/workspace/presentation/widgets/conversation_thread.dart': 1,
  'lib/features/workspace/presentation/widgets/member_note_composer.dart': 1,
  'lib/features/workspace/presentation/widgets/public_holidays_sheet.dart': 1,
};

final _rawSpinner = RegExp(r'\bCircularProgressIndicator\(');

/// The primitives a screen state should be expressed with. Counted so a
/// fall in spinners that is really a fall in *state handling* is
/// visible: removing a spinner and showing nothing is not progress.
const _primitives = ['LoadingView(', 'EmptyState(', 'InlineBanner('];

void main() {
  test('no presentation file grows a raw spinner (#1305)', () {
    final grew = <String>[];
    final shrank = <String>[];
    final seen = <String>{};

    for (final file in handWrittenDartFiles('lib')) {
      if (!file.path.contains('/presentation/') &&
          !file.path.startsWith('lib/app/')) {
        continue;
      }
      final count = _rawSpinner
          .allMatches(file.readAsStringSync())
          .length;
      if (count > 0) seen.add(file.path);
      final allowed = _baseline[file.path] ?? 0;
      if (count > allowed) {
        grew.add('${file.path}: $count raw spinner(s), baseline $allowed');
      } else if (count < allowed) {
        shrank.add('${file.path}: $count (baseline $allowed)');
      }
    }

    expect(
      grew,
      isEmpty,
      reason: 'a raw CircularProgressIndicator says "something is '
          'happening" and nothing else — not what is loading, not '
          'whether what is on screen is still valid, not what to do if '
          'it never finishes:\n${grew.join('\n')}\n\n'
          'Use LoadingView for a screen that has no data yet, keep '
          'existing content visible while refreshing, and say what '
          'failed with InlineBanner or AppSnack (#1305).',
    );

    expect(
      shrank,
      isEmpty,
      reason: 'good — lower these in _baseline in the same commit, so '
          'the next person inherits the ground you took:\n'
          '${shrank.join('\n')}',
    );

    final gone = _baseline.keys.where((p) => !seen.contains(p)).toList();
    expect(
      gone,
      isEmpty,
      reason: 'these no longer build a raw spinner — delete them from '
          '_baseline so the ratchet keeps its meaning:\n${gone.join('\n')}',
    );
  });

  test('the state primitives are still the house idiom', () {
    // A guard on the guard: if somebody "fixed" the spinner count by
    // deleting the primitives instead of adopting them, the ratchet
    // above would read as progress. Counting both sides makes that
    // visible.
    var primitives = 0;
    for (final file in handWrittenDartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final primitive in _primitives) {
        primitives += primitive.allMatches(source).length;
      }
    }

    expect(
      primitives,
      greaterThanOrEqualTo(80),
      reason: 'LoadingView + EmptyState + InlineBanner were used 85 '
          'times across lib/ on 2026-09-16 (48 + 21 + 16). A sharp fall '
          'means screens stopped expressing their state rather than '
          'started — which is what the spinner ratchet would otherwise '
          'reward. The floor sits a little under the measurement so an '
          'honest refactor that merges two call sites does not fail it.',
    );
  });
}
