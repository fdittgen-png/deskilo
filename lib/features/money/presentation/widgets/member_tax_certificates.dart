// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- a customer's exemption certificates, on the member's page of a
// seller in sales-tax mode: the ones on file, ending one, adding one. A
// certificate in force makes the taxable lines of the customer's invoice go out
// untaxed and cites it; it is never deleted, an issued invoice cites it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/tax_exemption_certificate.dart';
import '../../providers/sales_tax_providers.dart';
import '../invoice_actions.dart';

String _kindName(AppLocalizations l10n, String kind) => switch (kind) {
  'resale' => l10n.taxCertKindResale,
  'nonprofit' => l10n.taxCertKindNonprofit,
  'government' => l10n.taxCertKindGovernment,
  _ => l10n.taxCertKindOther,
};

final _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime? _day(String text) =>
    _isoDay.hasMatch(text) ? DateTime.tryParse(text) : null;

/// The tile on a member's page: shown only to whoever manages billing, in a
/// space that issues in sales-tax mode.
class MemberTaxCertificatesTile extends ConsumerWidget {
  const MemberTaxCertificatesTile({
    super.key,
    required this.workspaceId,
    required this.memberId,
    required this.canManage,
  });

  final String workspaceId;
  final String memberId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canManage || !salesTaxModeOn(ref)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final today = isoDay(ref.watch(clockProvider).now());
    final inForce =
        (ref.watch(memberTaxCertificatesProvider(memberId)).value ??
                const <TaxExemptionCertificate>[])
            .where((c) => c.inForceOn(today))
            .length;
    return ListTile(
      key: const ValueKey('member-page-tax-certificates'),
      leading: const Icon(Icons.verified_user_outlined),
      title: Text(l10n.taxCertTitle),
      subtitle: Text(inForce == 0 ? l10n.taxCertEmpty : l10n.taxCertSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showMemberTaxCertificates(
        context,
        workspaceId: workspaceId,
        memberId: memberId,
      ),
    );
  }
}

/// The certificates on file for [memberId].
Future<void> _showMemberTaxCertificates(
  BuildContext context, {
  required String workspaceId,
  required String memberId,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      _CertificatesSheet(workspaceId: workspaceId, memberId: memberId),
);

class _CertificatesSheet extends ConsumerWidget {
  const _CertificatesSheet({required this.workspaceId, required this.memberId});

  final String workspaceId;
  final String memberId;

  Future<void> _end(
    BuildContext context,
    WidgetRef ref,
    TaxExemptionCertificate c,
  ) async {
    final today = ref.read(clockProvider).now();
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'tax certificate end failed',
      errorText: context.l10n.taxCertFailed,
      action: () =>
          ref.read(salesTaxCommandsProvider).endCertificate(c.id, today),
    );
    if (ok) ref.invalidate(memberTaxCertificatesProvider(memberId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = isoDay(ref.watch(clockProvider).now());
    final list =
        ref.watch(memberTaxCertificatesProvider(memberId)).value ??
        const <TaxExemptionCertificate>[];
    return SheetShell(
      title: l10n.taxCertTitle,
      children: [
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.taxCertEmpty,
              key: const ValueKey('tax-cert-empty'),
            ),
          ),
        for (final c in list)
          ListTile(
            key: ValueKey('tax-cert-${c.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_kindName(l10n, c.kind)} · ${c.number} (${c.state})',
            ),
            subtitle: Text(
              c.validTo == null
                  ? l10n.taxCertOpenEnded(c.validFrom)
                  : l10n.taxCertValidity(c.validFrom, c.validTo!),
            ),
            trailing: c.inForceOn(today) && c.validTo == null
                ? TextButton(
                    key: ValueKey('tax-cert-end-${c.id}'),
                    onPressed: () => _end(context, ref, c),
                    child: Text(l10n.taxCertEnd),
                  )
                : null,
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const ValueKey('tax-cert-add'),
          onPressed: () async {
            final saved = await _add(context, ref);
            if (saved) ref.invalidate(memberTaxCertificatesProvider(memberId));
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.taxCertAdd),
        ),
      ],
    );
  }

  Future<bool> _add(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fields = FormControllers({
      'state': '',
      'number': '',
      'from': isoDay(ref.read(clockProvider).now()),
      'to': '',
    });
    var kind = taxExemptionKinds.first;
    return showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.taxCertAdd,
        submitLabel: l10n.taxCertSave,
        submitKey: const ValueKey('tax-cert-save'),
        onDispose: fields.dispose,
        validate: () => {
          if (!RegExp(r'^([A-Za-z]{2}|\*)$').hasMatch(fields.text('state')))
            'state': l10n.taxCertInvalidState,
          if (fields.text('number').isEmpty) 'number': l10n.taxCertRequired,
          if (_day(fields.text('from')) == null)
            'from': l10n.taxCertInvalidDate,
          if (fields.text('to').isNotEmpty && _day(fields.text('to')) == null)
            'to': l10n.taxCertInvalidDate,
        },
        onSubmit: () async {
          try {
            await ref
                .read(salesTaxCommandsProvider)
                .saveCertificate(
                  TaxExemptionCertificateDraft(
                    workspaceId: workspaceId,
                    memberId: memberId,
                    kind: kind,
                    state: fields.text('state').toUpperCase(),
                    number: fields.text('number'),
                    validFrom: _day(fields.text('from'))!,
                    validTo: _day(fields.text('to')),
                  ),
                );
            return null;
          } on Object catch (e, st) {
            TraceLogger.instance.error(
              'money',
              'tax certificate save failed',
              error: e,
              stackTrace: st,
            );
            return l10n.taxCertFailed;
          }
        },
        builder: (context, refresh) => [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('tax-cert-kind'),
              initialValue: kind,
              decoration: InputDecoration(labelText: l10n.taxCertKind),
              items: [
                for (final k in taxExemptionKinds)
                  DropdownMenuItem(value: k, child: Text(_kindName(l10n, k))),
              ],
              onChanged: (x) => kind = x ?? kind,
            ),
          ),
          for (final (key, label) in [
            ('state', l10n.taxCertState),
            ('number', l10n.taxCertNumber),
            ('from', l10n.taxCertValidFrom),
            ('to', l10n.taxCertValidTo),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppTextField(
                key: ValueKey('tax-cert-$key'),
                controller: fields[key],
                fieldKey: key,
                label: label,
              ),
            ),
        ],
      ),
    );
  }
}
