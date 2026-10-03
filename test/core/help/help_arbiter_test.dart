// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1853 / #1867 — the one arbiter: a blocker outranks a guide step, a
// guide step outranks tips, and clearing restores the order.
import 'package:deskilo/core/help/help_arbiter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocker > guide > tips', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final arbiter = c.read(helpArbiterProvider.notifier);
    expect(c.read(helpSlotProvider), HelpSlot.tips);
    arbiter.guide(active: true);
    expect(c.read(helpSlotProvider), HelpSlot.guide);
    arbiter.blockerShown('closed-day');
    expect(c.read(helpSlotProvider), HelpSlot.blocker);
    arbiter.blockerShown('closed-day'); // idempotent
    arbiter.blockerCleared('closed-day');
    expect(c.read(helpSlotProvider), HelpSlot.guide);
    arbiter.guide(active: false);
    expect(c.read(helpSlotProvider), HelpSlot.tips);
  });

  test('two blockers: the slot stays blocked until both clear', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final arbiter = c.read(helpArbiterProvider.notifier)
      ..blockerShown('a')
      ..blockerShown('b')
      ..blockerCleared('a');
    expect(c.read(helpSlotProvider), HelpSlot.blocker);
    arbiter.blockerCleared('b');
    expect(c.read(helpSlotProvider), HelpSlot.tips);
  });
}
