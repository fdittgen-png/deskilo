// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_action_confirmation_repository.dart';
import '../domain/action_confirmation.dart';

part 'mcp_providers.g.dart';

@Riverpod(keepAlive: true)
ActionConfirmationRepository actionConfirmationRepository(Ref ref) =>
    SupabaseActionConfirmationRepository(Supabase.instance.client);

/// One confirmation, as the server answers it now.
@riverpod
Future<ActionConfirmation> actionConfirmation(Ref ref, String id) =>
    ref.watch(actionConfirmationRepositoryProvider).get(id);
