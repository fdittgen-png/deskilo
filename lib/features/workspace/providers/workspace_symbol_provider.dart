// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workspace_symbol.dart';
import 'workspace_providers.dart';

/// The decision to give a workspace its letters-on-a-colour symbol.
final workspaceSymbolsProvider = Provider.autoDispose<WorkspaceSymbols>(
  (ref) => WorkspaceSymbols(ref.watch(workspaceRepositoryProvider)),
);
