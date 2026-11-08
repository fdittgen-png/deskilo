// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403 -- the workspace's own tax reference, read where an action needs it.
// The packages take the reference as a parameter; the screens and the actions
// pass the one their workspace's context captured (never the process-wide
// static).
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operation_context_providers.dart';

/// The tax reference the selected workspace's context captured from its own
/// installation; null while none is ready.
TaxReferenceSet? workspaceTaxReference(WidgetRef ref) =>
    ref.read(readyWorkspaceContextProvider)?.taxReference.set;

/// [workspaceTaxReference], or a refusal for a flow that cannot go on without
/// it (the document builders): thrown inside the guarded action, which
/// answers with its generic message instead of a document built on a guess.
TaxReferenceSet requireWorkspaceTaxReference(WidgetRef ref) =>
    workspaceTaxReference(ref) ??
    (throw StateError('workspace context not ready'));
