// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — the rights requests a person files with a space: what they
// asked, when it was received, by when the space answers (a calendar
// month, or the extended date and its reason) and whether it was
// answered or refused. Filing works after leaving the space too.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/rights_requests.dart';
import '../../domain/rights_request.dart';
import '../../providers/profile_providers.dart';

String rightsKindLabel(AppLocalizations? l10n, String kind) => switch (kind) {
  'access' => l10n?.rightsKindAccess ?? 'See a copy of my data',
  'portability' =>
    l10n?.rightsKindPortability ?? 'Take my data elsewhere (machine-readable)',
  'rectification' => l10n?.rightsKindRectification ?? 'Correct my data',
  'restriction' =>
    l10n?.rightsKindRestriction ?? 'Restrict how my data is used',
  'objection' => l10n?.rightsKindObjection ?? 'Object to a use of my data',
  _ => l10n?.rightsKindErasure ?? 'Erase my data',
};

String rightsStatusLabel(
  AppLocalizations? l10n,
  RightsRequest request,
  DateFormat date,
) => switch (request.status) {
  'extended' =>
    l10n?.rightsStatusExtended(
          date.format(request.answerBy),
          request.extensionReason ?? '',
        ) ??
        'Extended to ${date.format(request.answerBy)}: '
            '${request.extensionReason ?? ''}',
  'completed' =>
    l10n?.rightsStatusCompleted ?? 'Answered — the space recorded what it did',
  'refused' =>
    l10n?.rightsStatusRefused(request.refusalReason ?? '') ??
        'Refused: ${request.refusalReason ?? ''}',
  _ =>
    l10n?.rightsStatusReceived(date.format(request.dueOn)) ??
        'Received — answer due by ${date.format(request.dueOn)}',
};

/// The Privacy & data row; [workspaceId] is the space the request goes to.
class RightsRequestsTile extends ConsumerWidget {
  const RightsRequestsTile({super.key, required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('privacy-rights-requests'),
      leading: const Icon(Icons.gavel_outlined),
      title: Text(l10n?.rightsRequestsTitle ?? 'My rights requests'),
      subtitle: Text(
        l10n?.rightsRequestsHint ??
            'Ask the space for a copy, a correction, a restriction or '
                'erasure — answered within one calendar month.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RightsRequestsSheet(workspaceId: workspaceId),
      ),
    );
  }
}

class _RightsRequestsSheet extends ConsumerWidget {
  const _RightsRequestsSheet({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final requests = ref.watch(myRightsRequestsProvider).value ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          key: const ValueKey('rights-requests-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.rightsRequestsTitle ?? 'My rights requests',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (requests.isEmpty)
              Text(l10n?.rightsRequestsEmpty ?? 'No request yet.'),
            for (final r in requests)
              ListTile(
                key: ValueKey('rights-request-${r.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(rightsKindLabel(l10n, r.kind)),
                subtitle: Text(rightsStatusLabel(l10n, r, date)),
              ),
            const SizedBox(height: AppSpacing.md),
            if (workspaceId != null)
              FilledButton.icon(
                key: const ValueKey('rights-request-new'),
                icon: const Icon(Icons.add),
                label: Text(l10n?.rightsRequestNew ?? 'Make a request'),
                onPressed: () => _new(context, ref, workspaceId!, date),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _new(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
    DateFormat date,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showDialog<({String kind, String details})>(
      context: context,
      builder: (_) => const _NewRightsRequestDialog(),
    );
    if (chosen == null || !context.mounted) return;
    // One id per submission: a retry after a lost answer is the same
    // request, never a second one.
    final clientRequestId = newClientRequestId();
    RightsRequest? sent;
    if (!await runGuarded(
      context,
      domain: 'privacy',
      message: 'rights request failed',
      errorText:
          l10n?.rightsRequestFailed ??
          'The request could not be sent. Please try again.',
      action: () async {
        sent = await submitRightsRequest(
          ref,
          workspaceId: workspaceId,
          kind: chosen.kind,
          details: chosen.details,
          clientRequestId: clientRequestId,
        );
      },
    )) {
      return;
    }
    if (!context.mounted || sent == null) return;
    AppSnack.success(
      context,
      l10n?.rightsRequestSent(date.format(sent!.answerBy)) ??
          'Request sent — the space answers by '
              '${date.format(sent!.answerBy)}.',
    );
  }
}

class _NewRightsRequestDialog extends StatefulWidget {
  const _NewRightsRequestDialog();

  @override
  State<_NewRightsRequestDialog> createState() =>
      _NewRightsRequestDialogState();
}

class _NewRightsRequestDialogState extends State<_NewRightsRequestDialog> {
  String _kind = rightsRequestKinds.first;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.rightsRequestAsk ?? 'What do you ask the space?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              key: const ValueKey('rights-requests-tile-radio-group'),
              groupValue: _kind,
              onChanged: (value) => setState(() => _kind = value ?? _kind),
              child: Column(
                children: [
                  for (final kind in rightsRequestKinds)
                    RadioListTile<String>(
                      key: ValueKey('rights-kind-$kind'),
                      contentPadding: EdgeInsets.zero,
                      value: kind,
                      title: Text(rightsKindLabel(l10n, kind)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('rights-request-details'),
              controller: _details,
              maxLength: 2000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n?.rightsRequestDetails ?? 'Details (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('rights-requests-tile-text-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('rights-request-send'),
          onPressed: () =>
              Navigator.of(context)
                  .pop((kind: _kind, details: _details.text.trim())),
          child: Text(l10n?.rightsRequestSend ?? 'Send the request'),
        ),
      ],
    );
  }
}
