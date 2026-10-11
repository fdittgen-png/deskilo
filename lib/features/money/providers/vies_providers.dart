// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — VIES checks of members' VAT numbers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/check_vies.dart';
import '../data/supabase_vies_repository.dart';
import '../domain/vies_check.dart';
import '../domain/vies_repository.dart';

part 'vies_providers.g.dart';

@Riverpod(keepAlive: true)
ViesRepository viesRepository(Ref ref) =>
    SupabaseViesRepository(Supabase.instance.client);

/// Checking a number now (the decision the member page asks for).
@riverpod
CheckVies checkVies(Ref ref) => CheckVies(ref.watch(viesRepositoryProvider));

/// The last check of one member's VAT number.
@riverpod
Future<ViesCheck> memberViesCheck(Ref ref, String memberId) =>
    ref.watch(viesRepositoryProvider).fetchViesCheck(memberId);
