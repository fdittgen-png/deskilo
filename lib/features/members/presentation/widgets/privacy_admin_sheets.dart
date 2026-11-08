// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — the sheets of the personal data admin's screen: record a request
// received elsewhere, extend its deadline, complete it with an outcome,
// refuse it with a reason, and record a privacy incident. Each shows the
// SERVER's reason when it refuses (the sheet stays open), because the right
// to decide is the server's and the person must be able to act on its words.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/rights_labels.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/application/privacy_admin.dart';

/// The words of a failed command: the server's message when it gave one.
String _reason(AppLocalizations l10n, Object e) =>
    l10n.privacyAdminActionFailed(commandFailureReason(e));

PrivacyAdminCommands _commands(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false)
        .read(privacyAdminCommandsProvider);

/// Runs [action]; null when it worked, the reason when it did not.
Future<String?> _attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  final l10n = context.l10n;
  try {
    await action();
    return null;
  } on Object catch (e, st) {
    TraceLogger.instance.error('privacy', 'privacy admin command failed',
        error: e, stackTrace: st);
    return _reason(l10n, e);
  }
}

/// Record a request the controller received outside the app.
Future<void> showRecordRequestSheet(
  BuildContext context, {
  required String workspaceId,
  required List<({String id, String name})> members,
  required DateTime today,
}) async {
  final l10n = context.l10n;
  final fields = FormControllers();
  String? memberId = members.isEmpty ? null : members.first.id;
  var kind = rightsRequestKinds.first;
  var received = DateTime(today.year, today.month, today.day);
  await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.privacyAdminRecord,
      submitLabel: l10n.privacyAdminSave,
      submitKey: const ValueKey('privacy-admin-record-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (memberId == null) 'member': l10n.privacyAdminMember,
      },
      onSubmit: () => _attempt(
        context,
        () async {
          await _commands(context).record(
            workspaceId: workspaceId,
            memberId: memberId!,
            kind: kind,
            details: fields.text('details'),
            receivedAt: received,
          );
        },
      ),
      builder: (ctx, refresh) => [
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const ValueKey('privacy-admin-member'),
          initialValue: memberId,
          decoration: InputDecoration(labelText: l10n.privacyAdminMember),
          items: [
            for (final m in members)
              DropdownMenuItem(value: m.id, child: Text(m.name)),
          ],
          onChanged: (v) {
            memberId = v;
            refresh();
          },
        ),
        const FormGap(),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const ValueKey('privacy-admin-kind'),
          initialValue: kind,
          decoration: InputDecoration(labelText: l10n.privacyAdminKind),
          items: [
            for (final k in rightsRequestKinds)
              DropdownMenuItem(value: k, child: Text(rightsKindLabel(l10n, k))),
          ],
          onChanged: (v) {
            kind = v ?? kind;
            refresh();
          },
        ),
        const FormGap(),
        ListTile(
          key: const ValueKey('privacy-admin-received'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.privacyAdminReceivedOn(isoDay(received))),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: received,
              firstDate: DateTime(today.year - 1, today.month, today.day),
              lastDate: DateTime(today.year, today.month, today.day),
            );
            if (picked != null) {
              received = picked;
              refresh();
            }
          },
        ),
        const FormGap(),
        AppTextField(
          controller: fields['details'],
          label: l10n.privacyAdminDetails,
          maxLines: 3,
        ),
      ],
    ),
  );
}

/// Extend the answer date once, with a reason.
Future<void> showExtendSheet(BuildContext context, RightsRequest request) {
  final l10n = context.l10n;
  final fields = FormControllers();
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.privacyAdminExtend,
      submitLabel: l10n.privacyAdminSave,
      submitKey: const ValueKey('privacy-admin-extend-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (fields.text('reason').length < 10)
          'reason': l10n.privacyAdminExtendReason,
      },
      onSubmit: () => _attempt(
        context,
        () => _commands(context)
            .extend(request, reason: fields.text('reason'))
            .then((_) {}),
      ),
      builder: (ctx, refresh) => [
        AppTextField(
          controller: fields['reason'],
          fieldKey: 'reason',
          label: l10n.privacyAdminExtendReason,
          maxLines: 3,
        ),
      ],
    ),
  );
}

/// Refuse a request with its reason.
Future<void> showRefuseSheet(BuildContext context, RightsRequest request) {
  final l10n = context.l10n;
  final fields = FormControllers();
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.privacyAdminRefuse,
      submitLabel: l10n.privacyAdminSave,
      submitKey: const ValueKey('privacy-admin-refuse-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (fields.text('reason').length < 10)
          'reason': l10n.privacyAdminRefusalReason,
      },
      onSubmit: () => _attempt(
        context,
        () => _commands(context)
            .refuse(request, reason: fields.text('reason'))
            .then((_) {}),
      ),
      builder: (ctx, refresh) => [
        AppTextField(
          controller: fields['reason'],
          fieldKey: 'reason',
          label: l10n.privacyAdminRefusalReason,
          maxLines: 3,
        ),
      ],
    ),
  );
}

const _outcomeKinds = [
  'removed',
  'corrected',
  'restricted',
  'retained',
  'pending_external',
  'failed',
];

String _outcomeLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'removed' => l10n.privacyOutcomeRemoved,
  'corrected' => l10n.privacyOutcomeCorrected,
  'restricted' => l10n.privacyOutcomeRestricted,
  'retained' => l10n.privacyOutcomeRetained,
  'pending_external' => l10n.privacyOutcomePendingExternal,
  _ => l10n.privacyOutcomeFailed,
};

/// Complete a request: one store and what happened to it (a retained one
/// also says why and for how long, as the server requires).
Future<void> showCompleteSheet(BuildContext context, RightsRequest request) {
  final l10n = context.l10n;
  final fields = FormControllers();
  var outcome = _outcomeKinds.first;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.privacyAdminComplete,
      submitLabel: l10n.privacyAdminSave,
      submitKey: const ValueKey('privacy-admin-complete-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (fields.text('store').isEmpty) 'store': l10n.privacyAdminStore,
        if (outcome == 'retained' && fields.text('basis').isEmpty)
          'basis': l10n.privacyAdminBasis,
        if (outcome == 'retained' && fields.text('period').isEmpty)
          'period': l10n.privacyAdminPeriod,
      },
      onSubmit: () => _attempt(
        context,
        () => _commands(context)
            .complete(request, outcome: {
              outcome: [
                {
                  'store': fields.text('store'),
                  if (outcome == 'retained') ...{
                    'basis': fields.text('basis'),
                    'period': fields.text('period'),
                  },
                },
              ],
            })
            .then((_) {}),
      ),
      builder: (ctx, refresh) => [
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const ValueKey('privacy-admin-outcome'),
          initialValue: outcome,
          decoration: InputDecoration(labelText: l10n.privacyAdminOutcomeKind),
          items: [
            for (final k in _outcomeKinds)
              DropdownMenuItem(value: k, child: Text(_outcomeLabel(l10n, k))),
          ],
          onChanged: (v) {
            outcome = v ?? outcome;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          controller: fields['store'],
          fieldKey: 'store',
          label: l10n.privacyAdminStore,
        ),
        if (outcome == 'retained') ...[
          const FormGap(),
          AppTextField(
            controller: fields['basis'],
            fieldKey: 'basis',
            label: l10n.privacyAdminBasis,
          ),
          const FormGap(),
          AppTextField(
            controller: fields['period'],
            fieldKey: 'period',
            label: l10n.privacyAdminPeriod,
          ),
        ],
      ],
    ),
  );
}

/// Record a privacy incident: its kind and what happened.
Future<void> showIncidentSheet(
  BuildContext context, {
  required String workspaceId,
}) async {
  final l10n = context.l10n;
  final fields = FormControllers();
  var kind = privacyIncidentKinds.first;
  int? told;
  final done = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.privacyAdminIncidentTitle,
      submitLabel: l10n.privacyAdminIncidentSend,
      submitKey: const ValueKey('privacy-admin-incident-send'),
      onDispose: fields.dispose,
      onSubmit: () => _attempt(
        context,
        () async {
          told = await _commands(context).recordIncident(
            workspaceId: workspaceId,
            kind: kind,
            note: fields.text('note'),
          );
        },
      ),
      builder: (ctx, refresh) => [
        Text(l10n.privacyAdminIncidentIntro),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const ValueKey('privacy-admin-incident-kind'),
          initialValue: kind,
          decoration: InputDecoration(labelText: l10n.privacyAdminKind),
          items: [
            DropdownMenuItem(
              value: 'data_breach',
              child: Text(l10n.privacyIncidentDataBreach),
            ),
            DropdownMenuItem(
              value: 'wrong_invoice',
              child: Text(l10n.privacyIncidentWrongInvoice),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text(l10n.privacyIncidentOther),
            ),
          ],
          onChanged: (v) {
            kind = v ?? kind;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          controller: fields['note'],
          label: l10n.privacyAdminIncidentNote,
          maxLines: 4,
          maxLength: 1000,
        ),
      ],
    ),
  );
  if (done && told != null && context.mounted) {
    AppSnack.success(context, l10n.privacyAdminIncidentRecorded(told!));
  }
}
