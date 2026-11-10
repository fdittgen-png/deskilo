// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3489 -- the instance doctor's words are ARB, not core literals. Counted:
// hand-made plurals are at 0 for good; the English sentences still in
// lib/core/instance only fall (the rest moves to ARB in the follow-up).
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _sentenceCeiling = 0;

void main() {
  final files = filesUnder(['lib/core/instance']);

  test('no hand-made plural in lib/core/instance', () {
    final kinds = [
      LiteralKind('hand-made plural', RegExp(r"== 1 \? '' : 's'")),
    ];
    final perFile = countLiterals(files, kinds)['hand-made plural']!;
    expect(
      total(perFile),
      0,
      reason: ratchetMessage(
        rule: 'instance doctor (#3489): use an ICU plural from instance_doctor_*.arb',
        kind: 'hand-made plural',
        ceiling: 0,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
  });

  test('English sentences in the doctor only fall', () {
    final kinds = [
      LiteralKind(
        'sentence literal',
        RegExp(r"'[A-Z][a-z]+ [^']{12,}'"),
      ),
    ];
    final doctor = files.where(
      (f) =>
          f.path.endsWith('instance_doctor.dart') ||
          f.path.endsWith('instance_security_checks.dart'),
    );
    final perFile = countLiterals(doctor, kinds)['sentence literal']!;
    expect(
      total(perFile),
      _sentenceCeiling,
      reason: ratchetMessage(
        rule: 'instance doctor (#3489): sentences belong in ARB',
        kind: 'sentence literal',
        ceiling: _sentenceCeiling,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
  });
}
