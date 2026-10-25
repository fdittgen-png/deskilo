// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The save step of the supplier form. The save runs while the form is
// open, so a refusal or a dropped connection keeps every value typed; it
// cannot run twice at once; a supplier already carrying the identifier is
// named before any attempt (the server refuses the same duplicate), and
// one with the same name is a caution that never blocks.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_prefill.dart';

/// What the save step shows, as one value: a change replaces it whole.
class SupplierSaveState {
  const SupplierSaveState({
    this.busy = false,
    this.problem,
    this.duplicate,
    this.similar,
    this.nameError,
  });

  /// A save is under way: Save, Cancel and the fields are off.
  final bool busy;

  /// Why the last attempt did not save, under the last field.
  final String? problem;

  /// The supplier that already carries the identifier.
  final Supplier? duplicate;

  /// Another supplier with the same name: a caution, never a block.
  final Supplier? similar;

  /// Under the name field.
  final String? nameError;
}

/// The save step's state and its two decisions: what an edit changes, and
/// what an attempt to save does.
class SupplierSaveStep extends ValueNotifier<SupplierSaveState> {
  SupplierSaveStep({required this.existing, required this.onSave})
    : super(const SupplierSaveState());

  /// The workspace's suppliers, which the duplicate checks read.
  final List<Supplier> existing;

  /// Saves a draft: the id saved, or null when nothing was sent.
  final Future<String?> Function(SupplierDraft draft) onSave;

  /// After an edit: the caution follows the name, and a name error stays
  /// only while the name is empty.
  void edited(SupplierDraft draft) {
    final now = value;
    final similar = supplierWithSimilarName(existing, draft);
    final nameError = draft.name.trim().isEmpty ? now.nameError : null;
    if (similar?.id == now.similar?.id && nameError == now.nameError) return;
    value = SupplierSaveState(
      busy: now.busy,
      problem: now.problem,
      duplicate: now.duplicate,
      similar: similar,
      nameError: nameError,
    );
  }

  /// One attempt. Returns the saved id, or null when the form stays open;
  /// [announce] hears every sentence the step shows. A second call while
  /// one runs does nothing.
  Future<String?> submit(
    SupplierDraft draft,
    AppLocalizations l10n, {
    required void Function(String text) announce,
  }) async {
    if (value.busy) return null;
    final similar = value.similar;
    void show({String? problem, Supplier? duplicate, String? nameError}) {
      value = SupplierSaveState(
        problem: problem,
        duplicate: duplicate,
        similar: similar,
        nameError: nameError,
      );
      final said = nameError ?? problem;
      if (said != null) announce(said);
    }

    if (draft.name.trim().isEmpty) {
      show(nameError: l10n.supplierNameMissing);
      return null;
    }
    final duplicate = supplierDuplicateOf(existing, draft);
    if (duplicate != null) {
      show(
        problem: l10n.supplierLookupDuplicate(
          '${duplicate.number} · ${duplicate.name}',
        ),
        duplicate: duplicate,
      );
      return null;
    }
    value = SupplierSaveState(busy: true, similar: similar);
    announce(l10n.supplierSaving);
    try {
      final id = await onSave(draft);
      if (id == null) show();
      return id;
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'supplier save failed',
        error: e,
        stackTrace: st,
      );
      show(problem: l10n.suppliersRefused);
      return null;
    }
  }
}

/// The save step's words under the last field: a refusal or a duplicate
/// (with the way to the supplier already there), the caution about a same
/// name, the progress.
class SupplierSaveStatus extends StatelessWidget {
  const SupplierSaveStatus({
    required this.state,
    required this.onOpen,
    super.key,
  });

  final SupplierSaveState state;

  /// Open a supplier already there instead of saving another.
  final ValueChanged<Supplier> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duplicate = state.duplicate;
    final similar = state.similar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.problem case final problem?) ...[
          const FormGap(),
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              key: const ValueKey('supplier-save-problem'),
              icon: duplicate != null
                  ? Icons.people_outline
                  : Icons.error_outline,
              text: problem,
              actionLabel: duplicate == null
                  ? null
                  : l10n.supplierLookupOpenExisting,
              onAction: duplicate == null ? null : () => onOpen(duplicate),
            ),
          ),
        ] else if (similar != null) ...[
          const FormGap(),
          InlineBanner(
            key: const ValueKey('supplier-similar-name'),
            icon: Icons.people_outline,
            severity: InlineBannerSeverity.info,
            text: l10n.supplierSimilarName(
              '${similar.number} · ${similar.name}',
            ),
            actionLabel: l10n.supplierLookupOpenExisting,
            onAction: () => onOpen(similar),
          ),
        ],
        if (state.busy) ...[
          const FormGap.small(),
          LinearProgressIndicator(
            key: const ValueKey('supplier-save-progress'),
            semanticsLabel: l10n.supplierSaving,
          ),
        ],
      ],
    );
  }
}
