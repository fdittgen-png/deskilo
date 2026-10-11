// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../domain/workspace_template.dart';
import '../../providers/workspace_providers.dart';

/// #1120 — who a template is shared with, and the way to invite one more
/// address or take one back. By ADDRESS: the server never says whether
/// an account exists behind it, so this sheet cannot be an oracle.
Future<void> showTemplateShareSheet(
    BuildContext context, WidgetRef ref, WorkspaceTemplate t) async {
  final l10n = context.l10n;
  final repo = ref.read(workspaceRepositoryProvider);
  final email = TextEditingController();
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md),
        child: FutureBuilder<List<String>>(
          future: repo.workspaceTemplateGrantees(t.id),
          builder: (ctx, snap) {
            final grantees = snap.data ?? const <String>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.libraryShareTitle(t.name),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.libraryShareHint,
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                if (grantees.isEmpty)
                  Text(l10n.libraryShareNobody,
                      style: Theme.of(ctx).textTheme.bodySmall),
                for (final g in grantees)
                  ListTile(
                    key: ValueKey('share-grantee-$g'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline),
                    title: Text(g),
                    trailing: IconButton(
                      key: ValueKey('share-revoke-$g'),
                      tooltip: MaterialLocalizations.of(ctx).deleteButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        if (await runGuarded(ctx,
                            domain: 'workspace',
                            message: 'revoke template grant failed',
                            action: () => repo.revokeWorkspaceTemplateGrant(t.id, g))) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('share-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                          labelText: l10n.libraryShareEmail),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('share-add'),
                    onPressed: () async {
                      final e = email.text.trim();
                      if (!e.contains('@')) return;
                      if (await runGuarded(ctx,
                          domain: 'workspace',
                          message: 'grant template failed',
                          action: () => repo.grantWorkspaceTemplate(t.id, e))) {
                        email.clear();
                        setState(() {});
                      }
                    },
                    child: Text(l10n.libraryShareAdd),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    ),
  );
  ref.invalidate(workspaceTemplatesProvider);
}
