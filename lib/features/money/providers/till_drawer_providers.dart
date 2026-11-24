// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/server_error.dart';
import '../domain/till_day.dart';
import '../domain/till_drawer.dart';

/// #4367 -- the cash drawer's server: tills, sessions, cash entries and the count. The app wires the live one
/// (`tillDrawerPortFromApp`); the Demo and the tests replace it.
final tillDrawerPortProvider = Provider<TillDrawerPort>((ref) => throw UnimplementedError('the till drawer port is wired by the app'));

/// #4367 -- the tills of the business with the session open on each, read again when a screen opens or an act changes them.
final tillDrawerProvider = FutureProvider.autoDispose.family<List<DrawerTill>, String>(
  (ref, workspaceId) => ref.watch(tillDrawerPortProvider).tills(workspaceId),
  retry: (_, _) => null,
);

/// #4367 -- what the open session should hold, or null when the server does not give it: the drawer is counted blind and
/// the person may not see the finances (DKN01). Any other refusal is an error the screen says.
final drawerExpectedProvider = FutureProvider.autoDispose.family<DrawerCash?, ({String workspaceId, String sessionId})>(
  (ref, key) async {
    try {
      return await ref.watch(tillDrawerPortProvider).expected(key.workspaceId, sessionId: key.sessionId);
    } on Object catch (e, st) {
      if (serverErrorCode(e) == DkCode.dkn01) return null;
      Error.throwWithStackTrace(e, st);
    }
  },
  retry: (_, _) => null,
);

/// #4367 -- how this business counts its drawer: by denomination or in total, the reasons of a cash entry and the largest
/// paid-out without a second person. The app wires it from the business's settings (`drawerSettingsFromApp`, where the registry
/// default stands for what the business set nothing of); the Demo and the tests replace it.
final drawerSettingsProvider = FutureProvider.autoDispose<DrawerSettings>(
  (ref) => throw UnimplementedError('the drawer settings are wired by the app'),
  retry: (_, _) => null,
);

/// #4367 -- whether the business runs till sessions (a sale needs an open session on its till). Off until the app wires it from
/// the business's features (`tillSessionsFromApp`): a business that does not run them sells as before, on no till.
final tillSessionsEnabledProvider = Provider<bool>((ref) => false);

/// #4367 -- the days closed so far, the latest first; the finances read them.
final dayClosesProvider = FutureProvider.autoDispose.family<List<DayCloseRow>, String>(
  (ref, workspaceId) => ref.watch(tillDrawerPortProvider).dayCloses(workspaceId),
  retry: (_, _) => null,
);
