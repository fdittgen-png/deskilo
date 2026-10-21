// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the sheet in which the person answers an in-browser assistant's
// request that needs their confirmation. Confirm and Decline are equal and
// neither is preselected, as on the MCP confirmation screen whose words it
// uses; closing the sheet decides nothing.
import 'package:flutter/material.dart';

import '../core/l10n/context_l10n.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui/app_sheet.dart';
import '../features/mcp/presentation/mcp_operation_labels.dart';
import 'webmcp_confirmations.dart';

/// Shows [request]; true when the person confirmed, false when they
/// declined, null when they closed the sheet without answering.
Future<bool?> showWebMcpConfirmationSheet(
  BuildContext context,
  WebMcpConfirmationRequest request, {
  required String workspaceName,
}) {
  final l10n = context.l10n;
  final accept = request.input['accept'];
  return showAppSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mcpConfirmTitle,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.mcpConfirmWorkspace(workspaceName)),
            const SizedBox(height: AppSpacing.xs),
            Text(mcpOperationLabel(l10n, request.operation)),
            if (accept is bool) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(accept ? l10n.mcpConfirmApprove : l10n.mcpConfirmRefuse),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.mcpConfirmConsequence),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('webmcp-confirm-decline'),
                    onPressed: () => Navigator.of(sheet).pop(false),
                    child: Text(l10n.mcpConfirmDecline),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('webmcp-confirm-accept'),
                    onPressed: () => Navigator.of(sheet).pop(true),
                    child: Text(l10n.mcpConfirmAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
