// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 -- the till selling offline in the Demo: three cash sales made from the prices the till held are numbered 1 to 3 on the
// device, sent in order when the connection returns and all accepted, a second send records none of them twice, the drawer counted
// exactly equals the float plus the three sales, the day closes with them, and a sale sent into the closed session is refused.
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_till_offline_journey.dart';

void main() {
  test('the bakery sells three cash sales offline, syncs, and the day closes with them', () async {
    final f = await tillOfflineFacts();
    expect(f.numbers, [1, 2, 3]);
    // 2 x 2.10 milk + 8.90 mug + 24.00 beans
    expect(f.totalMinor, 420 + 890 + 2400);
    expect(f.accepted, 3);
    expect(f.replayed, 3, reason: 'the same batch again is answered, not recorded again');
    expect(f.expectedMinor, 15000 + 3710);
    expect(f.closed.differenceMinor, 0);
    expect(f.day.sessions.single.till, 'Front counter');
    expect(f.day.salesTotalMinor, 3710);
    expect(f.sentIntoClosed, 'DKL12');
    expect(f.waitingAfter, 1, reason: 'the late sale stays on the device for a manager');
  });
}
