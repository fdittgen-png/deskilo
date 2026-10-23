// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Messages badge of the Me layer stays current before the inbox is
// first opened: while the shell watches the badge refresh, the unified
// inbox is read again every inbox poll; once the shell lets go (the inbox
// is open and polls on its own), the refresh stops.
import 'package:deskilo/core/settings/messaging_windows.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/providers/messenger_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the badge refresh re-reads the inbox every poll, and stops '
      'when nobody watches it', (tester) async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        messagingWindowsProvider.overrideWithValue(MessagingWindows.defaults),
        unifiedInboxProvider.overrideWith((ref) async {
          reads++;
          return const UnifiedInbox([]);
        }),
      ],
    );
    addTearDown(container.dispose);
    final inbox = container.listen(unifiedInboxProvider, (_, _) {});
    addTearDown(inbox.close);
    final badge = container.listen(inboxBadgeRefreshProvider, (_, _) {});
    final poll = badge.read();
    expect(poll, MessagingWindows.defaults.inboxPoll);
    await tester.pump();
    expect(reads, 1);

    await tester.pump(poll);
    expect(reads, 2, reason: 'one poll later the badge was read again');
    await tester.pump(poll);
    expect(reads, 3);

    badge.close();
    await tester.pump();
    await tester.pump(poll * 3);
    expect(reads, 3, reason: 'the open inbox polls on its own');
  });
}
