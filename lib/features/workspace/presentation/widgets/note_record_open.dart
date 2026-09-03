// SPDX-License-Identifier: 0BSD
//
// #842 — a message can point at an alert, at the validation trail of
// one, and at the financial documents people actually argue about. Every
// reference opens the thing it names, and says so plainly when the thing
// is gone: a message keeps its words even when its target does not.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../money/domain/invoice_ubl.dart';
import '../../../money/domain/money_face.dart';
import '../../../money/providers/money_face_controller.dart';
import '../../../money/providers/money_focus_controller.dart';
import '../../../money/presentation/widgets/invoice_detail_sheet.dart';
import '../../../money/providers/money_providers.dart';
import '../../domain/member_note_refs.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../screens/inbox_screen.dart';

/// The icon a reference of [kind] wears, in the body and in the picker.
IconData noteRecordIcon(NoteRecordKind kind) => switch (kind) {
      NoteRecordKind.alert => Icons.notifications_none,
      NoteRecordKind.validation => Icons.how_to_reg_outlined,
      NoteRecordKind.invoice => Icons.receipt_long_outlined,
      NoteRecordKind.payment => Icons.payments_outlined,
      NoteRecordKind.refund => Icons.undo_outlined,
    };

/// Opens what a `[ref:…]` names, resolving live.
Future<void> openRecordById(
  BuildContext context,
  WidgetRef ref, {
  required NoteRecordKind kind,
  required String id,
}) async {
  switch (kind) {
    case NoteRecordKind.alert:
      openInbox(ref, InboxTab.alerts);
      context.go('/messages');
    case NoteRecordKind.validation:
      await showValidationTrailSheet(context, eventId: id);
    case NoteRecordKind.payment:
      // #720 — a payment lands on the Payments face of its own month,
      // which is why the reference carries the period as its id: there
      // is no per-payment page to open, and the month is where the
      // conversation about a payment actually happens.
      ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.payments);
      ref.read(moneyFocusControllerProvider.notifier).setPeriod(id);
      context.go('/money');
    case NoteRecordKind.invoice:
    case NoteRecordKind.refund:
      // A refund IS a credit note, so it opens as the document it is.
      final invoices = await ref.read(invoicesProvider.future);
      final invoice = invoices.where((i) => i.id == id).firstOrNull;
      if (!context.mounted) return;
      if (invoice == null) {
        AppSnack.error(
          context,
          AppLocalizations.of(context)?.noteRefGone ??
              'That reference no longer exists.',
        );
        return;
      }
      final matches = ref.read(invoiceMatchesProvider).value ?? const {};
      final country =
          ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
      await showInvoiceDetailSheet(
        context,
        invoice: invoice,
        match: matches[invoice.id],
        canIssue: ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.issueInvoices),
        isEu: isEuCountry(country),
      );
  }
}

/// The decision trail of one event, on its own, because that is what the
/// reference promised to open.
Future<void> showValidationTrailSheet(
  BuildContext context, {
  required String eventId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          child: EventValidationTrail(
            key: ValueKey('note-ref-trail-$eventId'),
            eventId: eventId,
          ),
        ),
      ),
    );
