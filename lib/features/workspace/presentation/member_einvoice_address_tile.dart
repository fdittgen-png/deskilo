// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/form_kit.dart';
import '../application/set_member_einvoice_address.dart';
import '../domain/member.dart';
import '../providers/workspace_providers.dart';

/// #2358 — the customer's e-invoicing address on the member page: where
/// a network delivers this member's invoices (BT-49) and the county of
/// its address (BT-54). Whoever may issue invoices sets it.
class MemberEInvoiceAddressTile extends ConsumerWidget {
  const MemberEInvoiceAddressTile({super.key, required this.member});

  final Member member;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final fields = FormControllers({
      'id': member.einvoiceEndpointId,
      'scheme': member.einvoiceEndpointScheme,
      'county': member.billingSubdivision,
    });
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memberEInvoiceAddressLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.memberEInvoiceAddressHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('member-einvoice-endpoint'),
                controller: fields['id'],
                label: l10n.eInvoiceEndpointIdField,
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('member-einvoice-scheme'),
                controller: fields['scheme'],
                label: l10n.eInvoiceEndpointSchemeField,
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('member-einvoice-subdivision'),
                controller: fields['county'],
                label: l10n.eInvoiceSubdivisionField,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('member-einvoice-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('member-einvoice-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    final id = fields['id'].text;
    final scheme = fields['scheme'].text;
    final county = fields['county'].text;
    fields.dispose();
    if (ok != true || !context.mounted) return;
    var changed = false;
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'member e-invoice address update failed',
      errorText: l10n.memberEInvoiceAddressFailed,
      action: () async {
        changed = await ref
            .read(memberEInvoiceAddressesProvider)
            .set(
              member,
              endpointId: id,
              endpointScheme: scheme,
              subdivision: county,
            );
      },
    );
    if (changed) ref.invalidate(workspaceMembersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final address = member.einvoiceEndpointId.isEmpty
        ? l10n.memberEInvoiceAddressNone
        : member.einvoiceEndpointScheme.isEmpty
        ? member.einvoiceEndpointId
        : '${member.einvoiceEndpointScheme}:${member.einvoiceEndpointId}';
    return ListTile(
      key: const ValueKey('member-page-einvoice-address'),
      leading: const Icon(Icons.alternate_email_outlined),
      title: Text(l10n.memberEInvoiceAddressLabel),
      subtitle: Text(address),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _edit(context, ref),
    );
  }
}
