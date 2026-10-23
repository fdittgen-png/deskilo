// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_sample_data_repository.dart';
import '../domain/sample_data.dart';
import 'operation_context_providers.dart';

part 'sample_data_providers.g.dart';

/// 0546 — sample data in the owner's test space.
@Riverpod(keepAlive: true)
SampleDataRepository sampleDataRepository(Ref ref) =>
    SupabaseSampleDataRepository(ref.watch(selectedWorkspaceClientProvider));

/// A refusal or a server without 0546 is an answer, not a hiccup.
Duration? _noRetry(int retryCount, Object error) => null;

/// The space's open sample batch, or null when it holds none.
@Riverpod(retry: _noRetry)
Future<SampleDataBatch?> sampleDataStatus(Ref ref, String workspaceId) =>
    ref.watch(sampleDataRepositoryProvider).status(workspaceId);
