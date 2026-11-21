// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the kind each of my businesses set, for Me to name it.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_my_business_kinds.dart';
import '../domain/my_business_kinds.dart';
import 'workspace_providers.dart';

final myBusinessKindsReaderProvider = Provider<MyBusinessKindsReader>(
  (ref) => SupabaseMyBusinessKinds(ref.watch(selectedWorkspaceClientProvider)),
);

/// The kind code of each business of mine that set one, by workspace id. A
/// failed read is an error the page leaves unsaid (a kind is a label, not
/// something the page depends on); it is never read as "no business".
final myBusinessKindsProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(myBusinessKindsReaderProvider).read(),
  retry: (_, _) => null,
);
