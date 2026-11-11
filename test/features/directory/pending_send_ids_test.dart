// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3745 -- a send keeps its request id until the server answers: the same
// text repeats with it, another text is another request, and an answered
// send starts afresh.
import 'package:deskilo/features/directory/domain/pending_send_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same text keeps its id until the send is settled', () {
    var n = 0;
    final ids = PendingSendIds(() => 'id-${++n}');
    expect(ids.idFor('thread-a', 'Hello'), 'id-1');
    expect(ids.idFor('thread-a', 'Hello'), 'id-1', reason: 'a repeat');
    expect(ids.idFor('thread-b', 'Hello'), 'id-2', reason: 'another thread');
    expect(ids.idFor('thread-a', 'Hello!'), 'id-3', reason: 'another text');
    ids.settled('thread-a');
    expect(ids.idFor('thread-a', 'Hello!'), 'id-4', reason: 'answered: new');
  });
}
