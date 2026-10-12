// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/mcp_connection.dart';
import '../../providers/mcp_consent_form_provider.dart';
import '../mcp_operation_labels.dart';

/// One workspace the assistant may be given, with its operations and
/// optional fields.
class ConsentWorkspaceCard extends ConsumerWidget {
  const ConsentWorkspaceCard(this.w, {super.key});

  final ConsentWorkspace w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final form = ref.watch(mcpConsentFormProvider);
    final notifier = ref.read(mcpConsentFormProvider.notifier);
    final chosen = form.chosen[w.id];
    return Card(
      key: ValueKey('mcp-consent-ws-${w.id}'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        children: [
          CheckboxListTile(
            key: ValueKey('mcp-consent-ws-toggle-${w.id}'),
            value: chosen != null && chosen.isNotEmpty,
            title: Text(w.name),
            onChanged: form.busy
                ? null
                : (on) => notifier.toggleWorkspace(w, on: on ?? false),
          ),
          if (chosen != null)
            for (final op in w.operations)
              CheckboxListTile(
                key: ValueKey('mcp-consent-op-${w.id}-$op'),
                dense: true,
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.md,
                ),
                value: chosen.contains(op),
                title: Text(mcpOperationLabel(l10n, op)),
                onChanged: form.busy
                    ? null
                    : (on) =>
                          notifier.toggleOperation(w.id, op, on: on ?? false),
              ),
          if (chosen != null && w.optionalFields.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Text(
                l10n.mcpConsentFieldsExplain,
                key: ValueKey('mcp-consent-fields-${w.id}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final field in w.optionalFields)
              CheckboxListTile(
                key: ValueKey('mcp-consent-field-${w.id}-$field'),
                dense: true,
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.md,
                ),
                value: form.fields[w.id]?.contains(field) ?? false,
                title: Text(mcpOptionalFieldLabel(l10n, field)),
                onChanged: form.busy
                    ? null
                    : (on) =>
                          notifier.toggleField(w.id, field, on: on ?? false),
              ),
          ],
        ],
      ),
    );
  }
}
