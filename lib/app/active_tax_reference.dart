// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2478 -- the installation's rows become the snapshot the VAT functions run
// on (the bundled copy stands until they arrive, and when they cannot).
//
// #2561 L4 -- a LEGACY ADAPTER, composed here because it joins two features:
// while a workspace is selected the snapshot is the one its context captured
// from the workspace's own installation (workspace), and the personal home's
// rows (money's store) only while no workspace is selected at all. While a
// capture is under way, or was refused, it keeps what it holds: the readers
// that must not see the previous workspace's rows read the context instead.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/vat/tax_reference_active.dart';
import '../features/money/providers/tax_reference_providers.dart';
import '../features/workspace/providers/workspace_providers.dart';

part 'active_tax_reference.g.dart';

@riverpod
void activeTaxReference(Ref ref) {
  final captured = ref.watch(readyWorkspaceContextProvider);
  if (captured != null) {
    ActiveTaxReference.install(captured.taxReference.set);
    return;
  }
  final context = ref.watch(workspaceContextProvider);
  if (context.isLoading || context.hasError) return;
  final set = ref.watch(taxReferenceSetProvider).value;
  if (set != null && !set.isEmpty) ActiveTaxReference.install(set);
}
