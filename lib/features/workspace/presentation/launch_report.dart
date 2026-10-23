// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2876 — the readiness report: every milestone the space chose, whether
// the server says it is reached, and the steps that are its evidence. The
// same lines feed the Launch page's copied text and the configuration PDF.
import '../../../l10n/app_localizations.dart';
import '../domain/launch_review.dart';
import '../domain/setup_status.dart';

/// One line of the report: a milestone, where it stands, its evidence.
typedef LaunchReportLine = ({String label, String value, String detail});

String _stateOf(AppLocalizations l10n, SetupStepStatus s) =>
    '${l10n.setupStepTitle(s.step)}: ${l10n.setupStateName(s.state.name)}';

List<LaunchReportLine> launchReportLines(
  AppLocalizations l10n,
  LaunchReview review,
) => [
  for (final m in review.milestones)
    (
      label: l10n.setupMilestoneName(m.status.milestone),
      value: m.status.reached
          ? l10n.setupLaunchReached
          : l10n.setupGuideProgress(m.status.ready, m.status.required),
      detail: m.evidence.map((s) => _stateOf(l10n, s)).join(' · '),
    ),
];

/// The report as text to copy or forward.
String launchReportText(AppLocalizations l10n, LaunchReview review) => [
  l10n.setupLaunchReportTitle,
  for (final line in launchReportLines(l10n, review)) ...[
    '',
    '${line.label} — ${line.value}',
    if (line.detail.isNotEmpty) line.detail,
  ],
].join('\n');

/// What only the operator can do, as text the owner forwards.
String launchOperatorText(AppLocalizations l10n, LaunchReview review) => [
  l10n.setupLaunchOperator,
  for (final s in review.operatorTasks) '- ${l10n.setupStepTitle(s.step)}',
].join('\n');
