// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — moving a payment credit to the member who actually paid.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/credit_move_commands.dart';
import '../data/supabase_credit_move_repository.dart';
import '../domain/credit_move.dart';
import 'credit_providers.dart';

final creditMoveRepositoryProvider = Provider<CreditMoveRepository>(
  (ref) => SupabaseCreditMoveRepository(ref.watch(moneyClientProvider)),
  name: 'creditMoveRepositoryProvider',
);

final creditMoveCommandsProvider = Provider<CreditMoveCommands>(
  (ref) => CreditMoveCommands(ref.watch(creditMoveRepositoryProvider)),
  name: 'creditMoveCommandsProvider',
);
