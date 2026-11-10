// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/instance/instance_bundle_asset.dart';
import '../../../../core/instance/instance_doctor.dart';
import '../../../../core/instance/instance_security_checks.dart' show heldInEnglish;
import '../../../../core/instance/management_api.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';

/// #1308 S3 — runs the doctor on a project and shows what it found:
/// *Protected* or *Attention required*, problems first, passed checks
/// folded away. Any alarm is reported through [onChecked] so the host can
/// hold its next step back; a warning is shown and does not block.
///
/// Built once, for the wizard's finish and for the Server screen's full
/// check (#1309). The token behind [api] lives in the host's state only.
class InstanceDoctorPanel extends ConsumerStatefulWidget {
  const InstanceDoctorPanel({
    super.key,
    required this.api,
    required this.projectRef,
    this.onChecked,
  });

  final SupabaseManagement api;
  final String projectRef;
  final ValueChanged<List<DoctorFinding>>? onChecked;

  @override
  ConsumerState<InstanceDoctorPanel> createState() =>
      _InstanceDoctorPanelState();
}

class _InstanceDoctorPanelState extends ConsumerState<InstanceDoctorPanel> {
  bool _running = false;
  List<DoctorFinding>? _findings;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final findings = await ref.read(instanceDoctorRunnerProvider)(
          widget.api, widget.projectRef);
      if (!mounted) return;
      setState(() => _findings = findings);
      widget.onChecked?.call(findings);
    } on Object catch (e, st) {
      TraceLogger.instance
          .warn('instance', 'doctor could not run', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = e is ManagementApiException && e.unauthorized
            ? (context.l10n.instanceTokenRefused)
            : '$e');
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final findings = _findings;
    final problems = [
      ...?findings?.where((f) => f.level == DoctorLevel.alarm),
      ...?findings?.where((f) => f.level == DoctorLevel.warn),
    ];
    final passed = findings?.where((f) => !f.isProblem).toList() ?? const [];
    final alarm = problems.any((f) => f.level == DoctorLevel.alarm);
    return Card(
      key: const ValueKey('instance-doctor'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (findings != null)
              ListTile(
                key: ValueKey(alarm
                    ? 'instance-doctor-attention'
                    : 'instance-doctor-protected'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(alarm
                    ? Icons.gpp_maybe_outlined
                    : Icons.verified_user_outlined),
                title: Text(alarm
                    ? (l10n.instanceDoctorAttention)
                    : (l10n.instanceDoctorProtected)),
              ),
            for (final f in problems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(f.level == DoctorLevel.alarm
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined),
                title: Text(_title(l10n, f)),
                subtitle: Text(_detail(l10n, f).replaceAll(RegExp(r'\n\s+'), '\n')),
              ),
            if (passed.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.instanceDoctorPassed(passed.length)),
                children: [
                  for (final f in passed)
                    ListTile(
                      dense: true,
                      title: Text(_title(l10n, f)),
                      subtitle: Text(_detail(l10n, f)),
                    ),
                ],
              ),
            if (findings != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  key: const ValueKey('instance-doctor-footer'),
                  problems.isEmpty
                      ? l10n.instanceDoctorAllHealthy
                      : l10n.instanceDoctorNeedsHuman(problems.length),
                ),
              ),
            if (_error case final error?)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            if (_running) const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('instance-doctor-run'),
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(findings == null
                  ? (l10n.instanceDoctorRun)
                  : (l10n.instanceDoctorRunAgain)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A probe's name in the member's language.
String _probe(AppLocalizations l10n, DoctorProbe probe) => switch (probe) {
  DoctorProbe.auth => l10n.instanceDoctorProbeAuth,
  DoctorProbe.signups => l10n.instanceDoctorProbeSignups,
  DoctorProbe.schema => l10n.instanceDoctorProbeSchema,
  DoctorProbe.security => l10n.instanceDoctorProbeSecurity,
  DoctorProbe.policies => l10n.instanceDoctorProbePolicies,
  DoctorProbe.storage => l10n.instanceDoctorProbeStorage,
  DoctorProbe.hardening => l10n.instanceDoctorProbeHardening,
  DoctorProbe.roles => l10n.instanceDoctorProbeRoles,
};

/// A finding's title in the member's language: the catalogue's wording where
/// the finding is typed, else the title as the doctor wrote it.
String _title(AppLocalizations l10n, DoctorFinding f) {
  final facts = f.facts;
  return switch (f.words) {
    null || DoctorWords.installationHeld => f.title,
    DoctorWords.stuckAccounts => l10n.instanceDoctorStuckTitle(f.count ?? 0),
    DoctorWords.probeFailed => l10n.instanceDoctorProbeFailedTitle(
      _probe(l10n, facts[0] as DoctorProbe),
    ),
    DoctorWords.signupsNobodyConfirmed => l10n.instanceDoctorSignupsNobodyTitle,
    DoctorWords.schemaNoVersion => l10n.instanceDoctorSchemaNoVersionTitle,
    DoctorWords.policyDriftSkipped =>
      l10n.instanceDoctorPolicyDriftSkippedTitle,
    DoctorWords.policiesMatch => l10n.instanceDoctorPoliciesMatchTitle,
    DoctorWords.storageScoped => l10n.instanceDoctorStorageScopedTitle,
    DoctorWords.guardRealtime => l10n.instanceDoctorGuardRealtimeTitle,
    DoctorWords.guardDefiner => l10n.instanceDoctorGuardDefinerTitle,
    DoctorWords.guardAnonView => l10n.instanceDoctorGuardAnonViewTitle,
    DoctorWords.guardSecretGrants => l10n.instanceDoctorGuardSecretGrantsTitle,
    DoctorWords.guardPublicBucket => l10n.instanceDoctorGuardPublicBucketTitle,
    DoctorWords.rolesUndeclared => l10n.instanceDoctorRolesUndeclaredTitle,
    DoctorWords.rolesUnknown => l10n.instanceDoctorRolesUnknownTitle,
  };
}

/// A finding's detail in the member's language. The held phrase of an
/// installation is worded from `instanceDoctorHeld`; the sentences the doctor
/// still writes itself stay as it wrote them.
String _detail(AppLocalizations l10n, DoctorFinding f) {
  final facts = f.facts;
  return switch (f.words) {
    null || DoctorWords.stuckAccounts => f.detail,
    DoctorWords.installationHeld when facts.length == 2 => f.detail.replaceFirst(
      heldInEnglish(facts[0] as int, facts[1] as int),
      l10n.instanceDoctorHeld(facts[0] as int, facts[1] as int),
    ),
    DoctorWords.installationHeld => f.detail,
    DoctorWords.probeFailed => l10n.instanceDoctorProbeFailedDetail(
      facts[1] as int,
      '${facts[2]}',
    ),
    DoctorWords.signupsNobodyConfirmed =>
      l10n.instanceDoctorSignupsNobodyDetail(facts[0] as int),
    DoctorWords.schemaNoVersion => l10n.instanceDoctorSchemaNoVersionDetail(
      facts[0] as int,
      facts[1] as int,
    ),
    DoctorWords.policyDriftSkipped =>
      l10n.instanceDoctorPolicyDriftSkippedDetail,
    DoctorWords.policiesMatch =>
      l10n.instanceDoctorPoliciesMatchDetail(facts[0] as int),
    DoctorWords.storageScoped =>
      l10n.instanceDoctorStorageScopedDetail(facts[0] as int),
    DoctorWords.guardRealtime =>
      l10n.instanceDoctorGuardRealtimeDetail('${facts[0]}'),
    DoctorWords.guardDefiner =>
      l10n.instanceDoctorGuardDefinerDetail('${facts[0]}'),
    DoctorWords.guardAnonView =>
      l10n.instanceDoctorGuardAnonViewDetail('${facts[0]}'),
    DoctorWords.guardSecretGrants =>
      l10n.instanceDoctorGuardSecretGrantsDetail('${facts[0]}'),
    DoctorWords.guardPublicBucket =>
      l10n.instanceDoctorGuardPublicBucketDetail('${facts[0]}'),
    DoctorWords.rolesUndeclared => l10n.instanceDoctorRolesUndeclaredDetail(
      l10n.instanceDoctorHeld(facts[0] as int, facts[1] as int),
    ),
    DoctorWords.rolesUnknown =>
      l10n.instanceDoctorRolesUnknownDetail('${facts[0]}'),
  };
}
