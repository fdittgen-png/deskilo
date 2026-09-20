// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1580 — the window gate while its data is still arriving.
//
// The gate used to substitute a value for every read that had not
// landed: all seven weekdays, no closures, default policies, a flexible
// grid and `WorkHours.defaults` — 08:00 to 17:00. The comment said the
// server stays the authority, which was true of one direction only.
//
// A space that opens at 07:00 had a legal 07:00 window refused by the
// client before the server was ever asked; a space open until 22:00 had
// an illegal 18:00 window offered. One line produced a false refusal AND
// a false permission, and neither is distinguishable, by the person
// reading it, from a real answer.
//
// Three cases, because "no gate" has two causes that must stay apart:
// the feature is off (nothing to wait for) and the data has not arrived
// (something to wait for, and something to say).
import 'dart:async';

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/reservations/presentation/booking_gate_scope.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

typedef _Seen = ({bool pending, bool hasGate});

/// Reads the two answers from inside the tree, so each test asserts
/// what a surface would actually see rather than calling a helper.
class _Probe extends ConsumerWidget {
  const _Probe(this.onBuild);

  final void Function(_Seen seen) onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild((
      pending: bookingDataPending(ref, watch: true),
      hasGate: bookingGateOf(ref, watch: true) != null,
    ));
    return const SizedBox.shrink();
  }
}

Future<_Seen> _pump(
  WidgetTester tester, {
  required Map<String, bool> flags,
  List<Override> extra = const [],
}) async {
  _Seen? seen;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
        ),
        ...extra,
      ],
      child: MaterialApp(home: _Probe((s) => seen = s)),
    ),
  );
  await tester.pumpAndSettle();
  return seen!;
}

void main() {
  testWidgets('while the hours are still arriving there is no gate at all',
      (tester) async {
    final seen = await _pump(
      tester,
      flags: const {'bookingGate': true},
      // The ONE read that never lands. Everything else resolves, so what
      // this measures is the missing piece and not the fixture.
      extra: [
        workHoursProvider.overrideWith((ref) => Completer<WorkHours>().future),
      ],
    );

    expect(seen.hasGate, isFalse,
        reason: 'a gate built on WorkHours.defaults answers 08:00–17:00 for '
            'a space that never said so — refusing a legal 07:00 window and '
            'offering an illegal 18:00 one');
    expect(seen.pending, isTrue,
        reason: 'and the surface must be able to say it is still asking, '
            'instead of showing an answer it does not have');
  });

  testWidgets('with everything resolved the gate is there', (tester) async {
    final seen = await _pump(tester, flags: const {'bookingGate': true});

    expect(seen.hasGate, isTrue);
    expect(seen.pending, isFalse,
        reason: 'nothing is outstanding, so nothing is announced');
  });

  testWidgets('with the feature off there is nothing to wait for',
      (tester) async {
    final seen = await _pump(
      tester,
      flags: const {'bookingGate': false},
      extra: [
        workHoursProvider.overrideWith((ref) => Completer<WorkHours>().future),
      ],
    );

    expect(seen.hasGate, isFalse);
    expect(seen.pending, isFalse,
        reason: 'off and pending are both "no gate", and a surface that '
            'confused them would sit on "checking…" for ever in a space '
            'that switched the gate off');
  });
}
