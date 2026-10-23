// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the workspace calendar and the tax reference are captured into
// the `WorkspaceContext` from the selected workspace's own installation. The
// process-wide statics (`WorkspaceTime`, `WorkHours.current`,
// `ActiveTaxReference`) stay a LEGACY ADAPTER fed from that context while
// #2564 moves their readers.
//
// Two ratchets over comment-free source: the number of hand-written lib
// files that still READ each static may only fall. And the adapter is
// written in named places only, each fed from the context (or, for the tax
// reference at boot, from the copy bundled with the app).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The files defining the statics: they do not count.
const _definitions = {
  'lib/core/time/workspace_time.dart',
  'lib/core/time/work_hours.dart',
  'lib/core/vat/tax_reference_active.dart',
};

/// Readers that may stay, each with its reason; they do not count.
const _allowed = <String, String>{
  'lib/core/demo/demo_workspace_context.dart':
      'a demonstration has no installation: its context takes the snapshot '
          'the app installed from its bundled copy',
};

/// Where the adapter is written, and from what.
const _installers = <String, String>{
  'lib/app/shell/shell_effects.dart':
      'zone and working day from readyWorkspaceContextProvider',
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart':
      'working day from workHoursProvider, which reads the context',
  'lib/app/active_tax_reference.dart':
      'tax reference from readyWorkspaceContextProvider',
  'lib/core/instance/tax_reference_bundle_asset.dart':
      'the bundled copy, once at start-up',
};

/// Moved readers: they take the context's calendar or tax reference and
/// must not go back to the statics.
const _clean = <String>[
  'lib/features/workspace/providers/kpi_providers.dart',
  'lib/features/workspace/providers/workspace_providers.dart',
  'lib/features/workspace/providers/operation_context_providers.dart',
  'lib/features/money/presentation/invoice_actions.dart',
  'lib/features/workspace/presentation/widgets/setup_obligations_card.dart',
];

/// RATCHET: files reading the calendar statics. Only falls.
const _calendarBudget = 56;

/// RATCHET: files reading the tax reference static. Only falls.
const _taxBudget = 21;

final _calendarRead = RegExp(r'\bWorkspaceTime\.(?!install\()|\bWorkHours\.current\b');
final _taxRead = RegExp(r'\bActiveTaxReference\.(?!install\()');
final _install = RegExp(r'\b(WorkspaceTime|WorkHours|ActiveTaxReference)\.install\(');

void main() {
  final files = [
    for (final f in handWrittenDartFiles('lib'))
      if (!_definitions.contains(f.path) && !_allowed.containsKey(f.path)) f,
  ];

  List<String> reading(RegExp pattern) => [
        for (final f in files)
          if (scanLines([f], pattern.hasMatch).isNotEmpty) f.path,
      ]..sort();

  void ratchet(String what, RegExp pattern, int budget, String name) {
    final now = reading(pattern);
    expect(
      now.length,
      lessThanOrEqualTo(budget),
      reason: 'new code reads the $what from the WorkspaceContext '
          '(workspaceContextProvider / readyWorkspaceContextProvider), not '
          'from the process-wide static. Files now:\n${now.join('\n')}',
    );
    expect(
      now.length,
      greaterThanOrEqualTo(budget),
      reason: 'progress: lower $name to ${now.length}',
    );
  }

  test('files reading the calendar statics only shrink', () {
    ratchet('calendar', _calendarRead, _calendarBudget, '_calendarBudget');
  });

  test('files reading the tax reference static only shrink', () {
    ratchet('tax reference', _taxRead, _taxBudget, '_taxBudget');
  });

  test('moved readers stay off the statics', () {
    for (final path in _clean) {
      expect(
        scanLines([File(path)],
            (l) => _calendarRead.hasMatch(l) || _taxRead.hasMatch(l)),
        isEmpty,
        reason: '$path reads the context',
      );
    }
  });

  test('the legacy adapter is written only where it is fed from the context',
      () {
    final writers = {
      for (final f in files)
        if (scanLines([f], _install.hasMatch).isNotEmpty) f.path,
    };
    expect(writers, _installers.keys.toSet());
  });
}
