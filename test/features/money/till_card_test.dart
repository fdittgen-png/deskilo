// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 -- the card at the till: the terminal's answer decides the sale. Accepted makes the sale with that tender (once),
// refused leaves the basket to be paid another way, and an answer that is lost leaves the sale waiting in the counter's
// book (never asked again) for someone who may see the finances.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:flutter_test/flutter_test.dart';

const _milk = 'demo-item-milk';

Future<(TillSession, DemoTill)> _ringUp() async {
  final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20);
  var n = 0;
  final s = TillSession(port: till, workspaceId: 'ws', requestIds: () => 'req-${++n}');
  await s.add(itemId: _milk, name: 'Oat milk', unit: 'piece');
  return (s, till);
}

void main() {
  test('an accepted card makes the sale with that tender, once, and the book shows it', () async {
    final (s, till) = await _ringUp();
    await s.payCard();
    final asked = s.state.value.card;
    expect(asked, isNotNull);
    await s.cardAnswer('accepted', providerRef: 'T-1');
    expect(s.state.value.sold, isNotNull);
    expect(s.state.value.problem, isNull);
    final book = await till.book('ws');
    expect(book.issued.single.number, s.state.value.sold!.number);
    expect(book.waiting, isEmpty);
  });

  test('a refused card takes nothing: the sale is still to be paid, and the card may be asked again', () async {
    final (s, till) = await _ringUp();
    await s.payCard();
    await s.cardAnswer('refused');
    expect(s.state.value.sold, isNull);
    expect(s.state.value.card, isNull);
    expect(s.state.value.problem, isA<TillCardDeclined>());
    expect((await till.book('ws')).issued, isEmpty);
    await s.payCard();
    expect(s.state.value.card, isNotNull);
  });

  test('a lost answer is never asked again: the sale waits in the book with its authorization', () async {
    final (s, till) = await _ringUp();
    await s.payCard();
    await s.cardAnswer('unknown');
    expect(s.state.value.cardUnknown, isTrue);
    expect(s.state.value.sold, isNull);
    final book = await till.book('ws');
    expect(book.waiting.single.openAuthorizations, hasLength(1));
  });
}
