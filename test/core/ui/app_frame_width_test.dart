// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: the destinations a person moves between (Reserve, Calendar,
// Alerts, Members, Finances) share one column width; only canvas screens are
// wider, and a prefix never matches a longer word (`/me` is not `/messages`).
import 'package:deskilo/core/ui/app_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the bar destinations share the reading column', () {
    for (final path in [
      '/reserve', '/calendar', '/messages', '/events', '/directory', '/money',
    ]) {
      expect(frameWidthFor(path), kReadingColumnMaxWidth, reason: path);
    }
  });

  test('canvas screens and Me keep the wide frame, children included', () {
    for (final path in ['/me', '/me/privacy', '/editor', '/kiosk', '/discover']) {
      expect(frameWidthFor(path), kAppFrameMaxWidth, reason: path);
    }
  });

  test('a longer word is not the prefix', () {
    expect(frameWidthFor('/messages'), kReadingColumnMaxWidth);
    expect(frameWidthFor('/members'), kReadingColumnMaxWidth);
    expect(frameWidthFor('/editorial'), kReadingColumnMaxWidth);
  });
}
