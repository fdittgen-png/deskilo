// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — the personal data admin's screen: the rights requests addressed to
// this workspace (to record, extend, complete or refuse) and the privacy
// incident (to record, which tells whoever holds the privacy right). It is
// open to holders of `managePrivacy` or `viewPersonalData` while the member
// data feature is on; the server asks `rights_controller` again for every
// write and shows its own reason when it refuses.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/rights_labels.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../profile/application/privacy_admin.dart';
import '../widgets/privacy_admin_sheets.dart';

class PrivacyAdminScreen extends ConsumerWidget {
  const PrivacyAdminScreen({super.key, this.desk});

  /// The desk's requests table, composed by the route (it reads the
  /// requests of the profile feature and is therefore app-layer
  /// composition); without it the page is the phone's cards.
  final Widget Function(PrivacyAdminSpace space)? desk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final space = ref.watch(privacyAdminSpaceProvider);
    // #3628 — at the desk the requests are a records table, a request beside
    // it; the page's two actions stand over the table.
    if (space != null &&
        desk != null &&
        WindowClass.of(context).index >= WindowClass.expanded.index) {
      // The title keeps the bar to itself; the two actions stand in a row
      // over the table, giving way before it (a title is never cut).
      return Scaffold(
        appBar: AppBar(title: PageTitle(l10n.privacyAdminTitle)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppSpacing.gutterAll,
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  _RecordButton(space: space),
                  _IncidentButton(space: space),
                ],
              ),
            ),
            Expanded(child: desk!(space)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: PageTitle(l10n.privacyAdminTitle)),
      body: space == null ? const LoadingView() : _Body(space: space),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.space});

  final PrivacyAdminSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = space.id;
    final requests = ref.watch(workspaceRightsRequestsProvider(workspaceId));
    final names = {for (final m in space.members) m.id: m.name};
    final date = appFormatOf(context).dates(DateShape.date);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: AppSpacing.gutterAll,
          children: [
            Text(l10n.privacyAdminIntro),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _RecordButton(space: space),
                _IncidentButton(space: space),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            requests.when(
              loading: () => const LoadingView(),
              error: (e, _) => InlineBanner(
                key: const ValueKey('privacy-admin-load-failed'),
                icon: Icons.error_outline,
                text: l10n.privacyAdminLoadFailed,
                actionLabel: l10n.commonRetry,
                onAction: () =>
                    ref.invalidate(workspaceRightsRequestsProvider(workspaceId)),
              ),
              data: (list) => list.isEmpty
                  ? Text(
                      l10n.privacyAdminEmpty,
                      key: const ValueKey('privacy-admin-empty'),
                    )
                  : Column(
                      children: [
                        for (final r in list)
                          RightsRequestCard(
                            request: r,
                            who: names[r.memberId] ?? '',
                            date: date,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Records a rights request received another way (letter, desk, phone).
class _RecordButton extends ConsumerWidget {
  const _RecordButton({required this.space});

  final PrivacyAdminSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.icon(
    key: const ValueKey('privacy-admin-record'),
    icon: const Icon(Icons.add),
    label: Text(context.l10n.privacyAdminRecord),
    onPressed: () => showRecordRequestSheet(
      context,
      workspaceId: space.id,
      members: space.members,
      today: ref.read(clockProvider).now(),
    ),
  );
}

/// Records a privacy incident.
class _IncidentButton extends StatelessWidget {
  const _IncidentButton({required this.space});

  final PrivacyAdminSpace space;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('privacy-admin-incident'),
    icon: const Icon(Icons.report_outlined),
    label: Text(context.l10n.privacyAdminIncidentTitle),
    onPressed: () => showIncidentSheet(context, workspaceId: space.id),
  );
}

/// One rights request: who, what, when, where it stands, and its actions
/// (#3628: also the record beside the desk's table).
class RightsRequestCard extends ConsumerWidget {
  const RightsRequestCard({
    super.key,
    required this.request,
    required this.who,
    required this.date,
  });

  final RightsRequest request;
  final String who;
  final DateFormat date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final open = request.status == 'received' || request.status == 'extended';
    final title = who.isEmpty
        ? rightsKindLabel(l10n, request.kind)
        : '$who — ${rightsKindLabel(l10n, request.kind)}';
    return Card(
      key: ValueKey('privacy-admin-request-${request.id}'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(l10n.privacyAdminReceivedOn(date.format(request.receivedAt))),
            Text(
              rightsStatusLabel(
                l10n,
                status: request.status,
                dueOn: request.dueOn,
                answerBy: request.answerBy,
                date: date,
                extensionReason: request.extensionReason,
                refusalReason: request.refusalReason,
              ),
            ),
            if (request.details.isNotEmpty) Text(request.details),
            if (open)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (request.status == 'received')
                    TextButton(
                      key: ValueKey('privacy-admin-extend-${request.id}'),
                      onPressed: () => showExtendSheet(context, request),
                      child: Text(l10n.privacyAdminExtend),
                    ),
                  TextButton(
                    key: ValueKey('privacy-admin-complete-${request.id}'),
                    onPressed: () => showCompleteSheet(context, request),
                    child: Text(l10n.privacyAdminComplete),
                  ),
                  TextButton(
                    key: ValueKey('privacy-admin-refuse-${request.id}'),
                    onPressed: () => showRefuseSheet(context, request),
                    child: Text(l10n.privacyAdminRefuse),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
