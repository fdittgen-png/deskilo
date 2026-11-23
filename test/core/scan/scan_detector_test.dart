// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the wedge detector on recorded timings: a burst typed faster than the gap and ended by Enter or
// Tab is a scan; a person typing, a burst that is too short and a terminator after a pause are not; a pause in the
// middle starts the collection again.
import 'package:deskilo/core/scan/scan_detector.dart';
import 'package:deskilo/core/scan/scan_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

/// Types [text] one key every [gap] ms from [start], returns the time of the last key.
int _type(ScanDetector d, String text, {required int gap, int start = 0}) {
  var t = start;
  for (final ch in text.split('')) {
    d.character(ch, _ms(t));
    t += gap;
  }
  return t - gap;
}

void main() {
  test('a fast burst ended by a terminator is a scan', () {
    final d = ScanDetector();
    final last = _type(d, '4006381333931', gap: 8);
    expect(d.terminator(_ms(last + 8)), '4006381333931');
    expect(d.pending, isEmpty, reason: 'the collection ended');
  });

  test('a person typing is never a scan: every key is slower than the gap', () {
    final d = ScanDetector();
    final last = _type(d, '4006381333931', gap: 180);
    expect(d.terminator(_ms(last + 180)), isNull);
  });

  test('a terminator after a pause is not a scan, even after a fast burst', () {
    final d = ScanDetector();
    final last = _type(d, '4006381333931', gap: 8);
    expect(d.terminator(_ms(last + 400)), isNull);
  });

  test('a pause in the middle starts again: only the fast part counts', () {
    final d = ScanDetector();
    var last = _type(d, 'abc', gap: 8);
    last = _type(d, '123456', gap: 8, start: last + 600);
    expect(d.terminator(_ms(last + 8)), '123456');
  });

  test('a burst shorter than the minimum is not a scan', () {
    final d = ScanDetector();
    final last = _type(d, 'ab', gap: 8);
    expect(d.terminator(_ms(last + 8)), isNull);
  });

  test('a slower scanner is taken when its gap is raised, and not before', () {
    final slow = ScanDetector();
    final last = _type(slow, 'MAG1-A03', gap: 90);
    expect(slow.terminator(_ms(last + 90)), isNull);
    final tolerant = ScanDetector(maxInterval: _ms(120));
    final last2 = _type(tolerant, 'MAG1-A03', gap: 90);
    expect(tolerant.terminator(_ms(last2 + 90)), 'MAG1-A03');
  });

  test('the device preferences survive their wire form and stay within their range', () {
    const prefs = ScanPrefs(intervalMs: 80, terminator: ScanTerminator.tab);
    final back = ScanPrefs.fromJson(prefs.toJson());
    expect((back.intervalMs, back.terminator), (80, ScanTerminator.tab));
    expect(ScanPrefs.fromJson({'interval_ms': 5}).intervalMs, ScanPrefs.minIntervalMs);
    expect(ScanPrefs.fromJson({'interval_ms': 9000}).intervalMs, ScanPrefs.maxIntervalMs);
    expect(ScanPrefs.fromJson('garbage').intervalMs, ScanPrefs.defaultIntervalMs);
    expect(ScanPrefs.fromJson({'terminator': 'nonsense'}).terminator, ScanTerminator.either);
  });
}
