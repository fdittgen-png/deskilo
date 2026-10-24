// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — the rights requests a person files with a space: what they
// asked, when it was received, by when the space answers (a calendar
// month, or the extended date and its reason) and whether it was
// answered or refused. Filing works after leaving the space too.
//
// #2558 — each request names the space it is addressed to, and an answered
// one says what the space kept, what is still open elsewhere and what it
// could not do, as the controller recorded it: "answered" alone would read
// as "all gone".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/rights_requests.dart';
import '../../domain/rights_request.dart';
import '../../providers/profile_providers.dart';
import 'erasure_preview_view.dart';

String _rightsKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'access' => l10n.rightsKindAccess,
  'portability' =>
    l10n.rightsKindPortability,
  'rectification' => l10n.rightsKindRectification,
  'restriction' =>
    l10n.rightsKindRestriction,
  'objection' => l10n.rightsKindObjection,
  _ => l10n.rightsKindErasure,
};

String _rightsStatusLabel(
  AppLocalizations l10n,
  RightsRequest request,
  DateFormat date,
) => switch (request.status) {
  'extended' =>
    l10n.rightsStatusExtended(
          date.format(request.answerBy),
          request.extensionReason ?? '',
        ),
  'completed' =>
    l10n.rightsStatusCompleted,
  'refused' =>
    l10n.rightsStatusRefused(request.refusalReason ?? ''),
  _ =>
    l10n.rightsStatusReceived(date.format(request.dueOn)),
};

/// The lines under a request: whom it went to, where it stands, and for an
/// answered one what was kept (with its period), still open elsewhere, or
/// not done.
String _rightsRequestLines(
  AppLocalizations l10n,
  RightsRequest request,
  DateFormat date,
  Map<String, String> spaceNames,
) {
  String stores(List<ErasureStore> list, {bool period = false}) => [
    for (final s in list)
      if (period && (s.period?.trim().isNotEmpty ?? false))
        '${erasureStoreLabel(l10n, s.store)} (${s.period!.trim()})'
      else
        erasureStoreLabel(l10n, s.store),
  ].join('; ');
  final kept = request.outcomeStores('retained');
  final pending = request.outcomeStores('pending_external');
  final failed = request.outcomeStores('failed');
  final space = spaceNames[request.workspaceId];
  return [
    if (space != null)
      l10n.rightsRequestTarget(space)
    else
      l10n.rightsRequestTargetUnknown,
    _rightsStatusLabel(l10n, request, date),
    if (kept.isNotEmpty) l10n.rightsOutcomeKept(stores(kept, period: true)),
    if (pending.isNotEmpty) l10n.rightsOutcomePending(stores(pending)),
    if (failed.isNotEmpty) l10n.rightsOutcomeFailed(stores(failed)),
  ].join('\n');
}

/// The Privacy & data row; [workspaceId] is the space the request goes to.
class RightsRequestsTile extends ConsumerWidget {
  const RightsRequestsTile({
    super.key,
    required this.workspaceId,
    this.spaceNames = const {},
  });

  final String? workspaceId;

  /// The name of each space the person can see, by id: a request names the
  /// space it went to, and a new one is filed only to a named space.
  final Map<String, String> spaceNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('privacy-rights-requests'),
      leading: const Icon(Icons.gavel_outlined),
      title: Text(l10n.rightsRequestsTitle),
      subtitle: Text(
        l10n.rightsRequestsHint,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showAppSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RightsRequestsSheet(
          workspaceId: workspaceId,
          spaceNames: spaceNames,
        ),
      ),
    );
  }
}

class _RightsRequestsSheet extends ConsumerWidget {
  const _RightsRequestsSheet({
    required this.workspaceId,
    required this.spaceNames,
  });

  final String? workspaceId;
  final Map<String, String> spaceNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final requests = ref.watch(myRightsRequestsProvider).value ?? const [];
    final target = spaceNames[workspaceId];
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          key: const ValueKey('rights-requests-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rightsRequestsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (requests.isEmpty)
              Text(l10n.rightsRequestsEmpty),
            for (final r in requests)
              ListTile(
                key: ValueKey('rights-request-${r.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(_rightsKindLabel(l10n, r.kind)),
                subtitle: Text(
                  _rightsRequestLines(l10n, r, date, spaceNames),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (workspaceId != null && target != null)
              FilledButton.icon(
                key: const ValueKey('rights-request-new'),
                icon: const Icon(Icons.add),
                label: Text(l10n.rightsRequestNew),
                onPressed: () => _new(context, ref, workspaceId!, target, date),
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
    String space,
    DateFormat date,
  ) async {
    final l10n = context.l10n;
    final chosen = await showDialog<({String kind, String details})>(
      context: context,
      builder: (_) => _NewRightsRequestDialog(space: space),
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
          l10n.rightsRequestFailed,
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
      l10n.rightsRequestSentTo(space, date.format(sent!.answerBy)),
    );
  }
}

class _NewRightsRequestDialog extends StatefulWidget {
  const _NewRightsRequestDialog({required this.space});

  /// The space the request goes to, named in the question.
  final String space;

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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.rightsRequestAskSpace(widget.space)),
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
                      title: Text(_rightsKindLabel(l10n, kind)),
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
                labelText: l10n.rightsRequestDetails,
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
          child: Text(l10n.rightsRequestSend),
        ),
      ],
    );
  }
}
