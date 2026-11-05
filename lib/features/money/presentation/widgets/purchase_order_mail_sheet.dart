// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — how the space e-mails its orders: the sender (an address of a
// domain the space verified at Resend), its name, and the Resend API key.
// The key is typed once and sent to the server, which keeps it in Vault;
// it is never shown again, and an empty field keeps the stored one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';

class PurchaseOrderMailSheet {
  const PurchaseOrderMailSheet(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Opens the settings of [workspaceId], filled from [current]. True once
  /// the server has them.
  Future<bool> open({
    required String workspaceId,
    required PurchaseOrderMailSettings? current,
  }) {
    final l10n = context.l10n;
    final fields = FormControllers({
      'sender': current?.senderEmail ?? '',
      'name': current?.senderName ?? '',
    });
    PurchaseOrderMailDraft draft() => PurchaseOrderMailDraft(
      senderEmail: fields.values['sender'] ?? '',
      senderName: fields.values['name'] ?? '',
      apiKey: fields['key'].text,
      revision: current?.revision ?? 0,
    );
    return showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.purchaseOrderMailSettings,
        submitLabel: l10n.purchaseOrderMailSave,
        submitKey: const ValueKey('purchase-order-mail-save'),
        onDispose: fields.dispose,
        validate: () => draft().validFor(current)
            ? const {}
            : {'sender': l10n.purchaseOrderMailInvalid},
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order mail settings save failed',
            errorText: l10n.purchaseOrderRefused,
            action: () => ref
                .read(purchaseOrderCommandsProvider)
                .saveMailSettings(workspaceId, draft()),
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('purchase-order-mail-sender'),
            controller: fields['sender'],
            fieldKey: 'sender',
            label: l10n.purchaseOrderMailSender,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            maxLength: 254,
          ),
          AppTextField(
            key: const ValueKey('purchase-order-mail-name'),
            controller: fields['name'],
            label: l10n.purchaseOrderMailSenderName,
            maxLength: 120,
          ),
          AppTextField(
            key: const ValueKey('purchase-order-mail-key'),
            controller: fields['key'],
            label: l10n.purchaseOrderMailKey,
            helper: (current?.hasApiKey ?? false)
                ? l10n.purchaseOrderMailKeyKept
                : null,
            obscureText: true,
            maxLength: 200,
          ),
        ],
      ),
    );
  }
}
