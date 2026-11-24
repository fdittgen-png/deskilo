// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:flutter_test/flutter_test.dart';

// #4436 -- a sale names the track IDs its goods lines took (0939's counter_line_tracks)
void main() {
  const finalized = {
    'receipt_id': 'r-1',
    'number': 'T-0001',
    'totals': {'net_minor': 1000, 'tax_minor': 200, 'gross_minor': 1200},
  };

  test('a lot row and a piece row read as received, numbers as Postgres sends them', () {
    final lot = TillTrack.fromJson({
      'line_id': 'l-1',
      'track_kind': 'lot',
      'track_code': 'SUP-LOT-7',
      'quantity': 2.5,
    });
    final piece = TillTrack.fromJson({
      'line_id': 'l-2',
      'track_kind': 'piece',
      'track_code': 'E28011700000020F',
      'quantity': 1,
    });
    expect([lot.kind, lot.code, lot.quantity], ['lot', 'SUP-LOT-7', 2.5]);
    expect(
      [piece.kind, piece.code, piece.quantity],
      ['piece', 'E28011700000020F', 1],
    );
  });

  test('a sale carries the tracks it was given, and none when it sold no traced goods', () {
    final traced = TillSold.fromJson(
      finalized,
      tracks: const [
        TillTrack(lineId: 'l-1', kind: 'lot', code: 'A', quantity: 1),
      ],
    );
    expect(traced.tracks.single.code, 'A');
    expect(TillSold.fromJson(finalized).tracks, isEmpty);
  });

  test('a track row of the wrong shape is refused, not read as empty', () {
    expect(
      () => TillTrack.fromJson({
        'line_id': 'l-1',
        'track_kind': 'lot',
        'quantity': 1,
      }),
      throwsA(anything),
    );
  });
}
