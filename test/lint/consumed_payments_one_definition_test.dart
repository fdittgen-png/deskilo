// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587, #3671 -- what is left of a payment is said once (`paymentUseOf` in
// `unassigned_money.dart`): the parts the junction rows settle (one payment
// may settle several invoices) and the credits moved to another member. A
// screen or a flow that reads only one of those offers a payment that is no
// longer there to give. So the two reads behind the definition are called
// from that file only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The one file that may call the two reads.
const _definition = 'lib/features/money/application/unassigned_money.dart';

/// A call on a receiver: `.fetchConsumedPaymentIds(` or `.movedCreditIds(`.
/// A repository that implements or forwards the read is not a caller.
final _call = RegExp(r'\.(fetchConsumedPaymentIds|movedCreditIds)\(');

void main() {
  test('what is left of a payment is read through their one definition', () {
    final callers = <String>[];
    for (final file in handWrittenDartFilesIn([
      for (final layer in ['application', 'presentation', 'providers'])
        'lib/features/money/$layer',
    ])) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == _definition) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_call.hasMatch(lines[i])) callers.add('$path:${i + 1}');
      }
    }
    expect(
      callers,
      isEmpty,
      reason:
          'call readPaymentUse (or use unassignedMoneyProvider) '
          'instead: a use built from one of the reads misses the others',
    );
  });

  test('the definition itself still calls both reads', () {
    final source = File(_definition).readAsStringSync();
    expect(_call.allMatches(source).map((m) => m.group(1)).toSet(), {
      'fetchConsumedPaymentIds',
      'movedCreditIds',
    });
  });
}
