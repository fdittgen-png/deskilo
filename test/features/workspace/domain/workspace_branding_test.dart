// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — the one reader of `workspaces.branding`.
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('#RRGGBB reads as opaque ARGB, either case; anything else as absent',
      () {
    expect(parseHexColor('#C2410C'), 0xFFC2410C);
    expect(parseHexColor('#c2410c'), 0xFFC2410C);
    expect(parseHexColor(' #1F3A5F '), 0xFF1F3A5F);
    expect(parseHexColor('C2410C'), isNull);
    expect(parseHexColor('#C2410'), isNull);
    expect(parseHexColor('#C2410CFF'), isNull);
    expect(parseHexColor(12), isNull);
    expect(parseHexColor(null), isNull);
    expect(hexOfColor(0xFFC2410C), '#C2410C');
    expect(hexOfColor(0xFF00000A), '#00000A');
  });

  test('the stored map reads whole; a malformed value reads as absent', () {
    final b = WorkspaceBranding.fromJson({
      'seed_color': '#C2410C',
      'office_palette': ['#EBDCC9', 'nope', '#CFE3DC'],
      'seat_palette': 'default',
      'emblem': 'a newer key',
    });
    expect(b.seedArgb, 0xFFC2410C);
    expect(b.officePalette, [0xFFEBDCC9, 0xFFCFE3DC]);
    expect(b.seatPalette, 'default');
    expect(b.isEmpty, isFalse);
  });

  test('nothing chosen is empty — the product palette', () {
    expect(const WorkspaceBranding().isEmpty, isTrue);
    expect(WorkspaceBranding.fromJson(const {}).isEmpty, isTrue);
    expect(WorkspaceBranding.fromJson({'seat_palette': 3}).isEmpty, isTrue);
  });
}
