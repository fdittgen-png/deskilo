// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/instance/instance_bundle_asset.dart';
import '../../../../core/instance/instance_doctor.dart';
import '../../../../core/instance/management_api.dart';
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
    } catch (e, st) {
      TraceLogger.instance
          .warn('instance', 'doctor could not run', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = e is ManagementApiException && e.unauthorized
            ? (AppLocalizations.of(context)?.instanceTokenRefused ??
                'Supabase refused the token.')
            : '$e');
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    ? (l10n?.instanceDoctorAttention ?? 'Attention required')
                    : (l10n?.instanceDoctorProtected ?? 'Protected')),
              ),
            for (final f in problems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(f.level == DoctorLevel.alarm
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined),
                title: Text(f.title),
                subtitle: Text(f.detail.replaceAll(RegExp(r'\n\s+'), '\n')),
              ),
            if (passed.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n?.instanceDoctorPassed(passed.length) ??
                    '${passed.length} checks passed'),
                children: [
                  for (final f in passed)
                    ListTile(
                      dense: true,
                      title: Text(f.title),
                      subtitle: Text(f.detail),
                    ),
                ],
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
                  ? (l10n?.instanceDoctorRun ?? 'Run the security check')
                  : (l10n?.instanceDoctorRunAgain ?? 'Check again')),
            ),
          ],
        ),
      ),
    );
  }
}
