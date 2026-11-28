// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show easAddressRefusal;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/einvoice_scheme_field.dart';
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
    // #4501 -- the dialog owns its fields, so they outlive its closing animation
    final picked = await showDialog<({String id, String scheme, String county})>(
      context: context,
      builder: (context) => _AddressDialog(member: member),
    );
    if (picked == null || !context.mounted) return;
    final (:id, :scheme, :county) = picked;
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

/// The address being edited, with its fields and the reason it cannot be stored.
class _AddressDialog extends StatefulWidget {
  const _AddressDialog({required this.member});

  final Member member;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final fields = FormControllers({
    'id': widget.member.einvoiceEndpointId,
    'scheme': widget.member.einvoiceEndpointScheme,
    'county': widget.member.billingSubdivision,
  });
  String? error;

  @override
  void dispose() {
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    return AlertDialog(
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
            EInvoiceSchemeField(
              key: const ValueKey('member-einvoice-scheme'),
              value: fields.text('scheme'),
              onChanged: (code) => setState(() {
                fields['scheme'].text = code;
                error = null;
              }),
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('member-einvoice-endpoint'),
              controller: fields['id'],
              label: l10n.eInvoiceEndpointIdField,
              error: error,
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('member-einvoice-save'),
          onPressed: () {
            final refusal = easAddressRefusal(
              fields.text('scheme'),
              fields.text('id'),
              storedScheme: member.einvoiceEndpointScheme,
              storedIdentifier: member.einvoiceEndpointId,
            );
            if (refusal == null) {
              return Navigator.of(context).pop((id: fields.text('id'), scheme: fields.text('scheme'), county: fields.text('county')));
            }
            setState(() => error = easRefusalText(l10n, refusal, fields.text('scheme')));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
