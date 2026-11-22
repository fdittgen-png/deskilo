// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the engagements of the services a business ordered.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/service_fulfilment_commands.dart';
import '../data/supabase_service_fulfilment_repository.dart';
import '../domain/service_fulfilment.dart';
import 'credit_providers.dart';

final serviceFulfilmentRepositoryProvider =
    Provider<ServiceFulfilmentRepository>(
      (ref) =>
          SupabaseServiceFulfilmentRepository(ref.watch(moneyClientProvider)),
    );

/// What the issuer does to an engagement.
final serviceFulfilmentCommandProvider = Provider<ServiceFulfilmentCommands>(
  (ref) =>
      ServiceFulfilmentCommands(ref.watch(serviceFulfilmentRepositoryProvider)),
);

/// The engagements of one workspace. A refusal (no right, switched off, an
/// older host) stays an error the screen words; it is never read as "none".
/// No silent retry: the screen offers its own.
final serviceFulfilmentsProvider = FutureProvider.autoDispose
    .family<List<ServiceFulfilment>, String>(
      (ref, workspaceId) => ref
          .watch(serviceFulfilmentRepositoryProvider)
          .fulfilments(workspaceId),
      retry: (_, _) => null,
    );

/// One engagement with its history and the documents beside it, as the server
/// answers now.
final serviceFulfilmentProvider = FutureProvider.autoDispose
    .family<ServiceFulfilment, ({String workspaceId, String fulfilmentId})>(
      (ref, key) => ref
          .watch(serviceFulfilmentRepositoryProvider)
          .fulfilment(key.workspaceId, key.fulfilmentId),
      retry: (_, _) => null,
    );
