// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403 -- the workspace's own tax reference, read where an action needs it.
// The packages take the reference as a parameter; the screens and the actions
// pass the one their workspace's context captured (never the process-wide
// static).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show isEuCountry;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/workspace_context_not_ready.dart';
import 'operation_context_providers.dart';

/// The tax reference the selected workspace's context captured from its own
/// installation; null while none is ready.
TaxReferenceSet? workspaceTaxReference(WidgetRef ref) =>
    ref.read(readyWorkspaceContextProvider)?.taxReference.set;

/// The workspace's day-of function (its calendar's `dateOf`, in the
/// workspace's own zone); null while no context is ready. Read it in the same
/// synchronous step as [workspaceTaxReference]: both come from the one
/// context, so they are present together.
DateTime Function(DateTime instant)? readyWorkspaceDayOf(WidgetRef ref) =>
    ref.read(readyWorkspaceContextProvider)?.calendar.dateOf;

/// [workspaceTaxReference] for a `build`: it watches, so the widget rebuilds
/// when the context becomes ready; null (draw nothing) until then.
TaxReferenceSet? watchWorkspaceTaxReference(WidgetRef ref) =>
    ref.watch(readyWorkspaceContextProvider)?.taxReference.set;

/// Whether [country] is an EU member state by the workspace's own tax
/// reference; false while that is not ready (the e-invoice affordance that
/// hangs on it then waits for the context).
bool workspaceIsEu(WidgetRef ref, String country) {
  final reference = workspaceTaxReference(ref);
  return reference != null && isEuCountry(country, reference: reference);
}

/// [workspaceIsEu] for a `build`: it watches, so the widget answers again when
/// the context becomes ready (a `build` never takes the read form).
bool watchWorkspaceIsEu(WidgetRef ref, String country) {
  final reference = watchWorkspaceTaxReference(ref);
  return reference != null && isEuCountry(country, reference: reference);
}

/// [workspaceTaxReference], or a refusal for a flow that cannot go on without
/// it (the document builders): thrown inside the guarded action, which
/// answers with its generic message instead of a document built on a guess.
TaxReferenceSet requireWorkspaceTaxReference(WidgetRef ref) =>
    workspaceTaxReference(ref) ??
    (throw const WorkspaceContextNotReady());
