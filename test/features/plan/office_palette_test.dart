// SPDX-License-Identifier: 0BSD
//
// #1289 — the plan paints the workspace's own fills, by the office's
// own stored index.
import 'package:deskilo/core/theme/office_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no palette: the product colours, unchanged', () {
    for (var i = 0; i < OfficeColors.palette.length + 3; i++) {
      expect(OfficeColors.of(i), OfficeColors.palette[i % 8]);
      expect(OfficeColors.of(i, from: const []), OfficeColors.palette[i % 8]);
    }
  });

  test("a workspace's fills are used in their own order, and an office "
      'keeps its slot when the palette is shorter', () {
    const own = [Color(0xFFEBDCC9), Color(0xFFCFE3DC), Color(0xFFD6DEEB)];
    expect(OfficeColors.of(0, from: own), own[0]);
    expect(OfficeColors.of(2, from: own), own[2]);
    // The seventh office of a space with three colours cycles — it does
    // not fall back to the product's seventh.
    expect(OfficeColors.of(7, from: own), own[1]);
    expect(OfficeColors.of(7, from: own), isNot(OfficeColors.palette[7]));
  });
}
