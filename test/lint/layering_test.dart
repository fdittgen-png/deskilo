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
/// one-line justification in the PR description. Counts per pair are
/// deliberately not tracked — they churn on every refactor and would
/// turn this file into a conflict magnet.
const Set<String> _knownPairs = {
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

Iterable<File> _featureFiles() => handWrittenDartFiles('lib/features');

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

  test('domain/ is pure Dart — no Flutter, no dart:ui', () {
    final violations = <String>[];
    for (final file in _featureFiles()) {
      if (!file.path.contains('/domain/')) continue;
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
      reason: 'domain/ must stay pure Dart (AGENT_RULES) — anything that '
          'paints, renders or touches a BuildContext belongs in '
          'presentation/:\n${violations.join('\n')}',
    );
  });

  test('cross-feature import pairs stay inside the committed set (ratchet)',
      () {
    final live = <String>{};
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
        if (target != null && target != src) live.add('$src -> $target');
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
  });
}
