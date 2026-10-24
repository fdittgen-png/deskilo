// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/instance/installation_enrolment.dart';
import '../../../../core/instance/management_api.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import 'instance_done_step.dart';

/// #2562 C2a — the optional wizard step that enrols the installation just
/// built at a personal home the same operator runs (another project the
/// token reaches). The facts are read from both projects and written by
/// the home's operator function; nothing is typed but the choice of home.
/// A combined installation skips it.
class InstanceEnrolStep extends StatefulWidget {
  const InstanceEnrolStep({
    super.key,
    required this.api,
    required this.projectRef,
    required this.homes,
  });

  final SupabaseManagement api;

  /// The installation being built.
  final String projectRef;

  /// The other projects the token reaches: the candidate homes.
  final List<SupabaseProject> homes;

  @override
  State<InstanceEnrolStep> createState() => _InstanceEnrolStepState();
}

class _InstanceEnrolStepState extends State<InstanceEnrolStep> {
  String? _home;
  bool _accepting = true;
  bool _busy = false;
  String? _done;
  String? _error;

  List<SupabaseProject> get _homes => [
    for (final p in widget.homes)
      if (p.ref != widget.projectRef) p,
  ];

  String _refusal(AppLocalizations l10n, EnrolmentRefused e, String home) =>
      switch (e.reason) {
        EnrolmentRefusal.notAWorkspaceHost => l10n.instanceEnrolNotHost,
        EnrolmentRefusal.notAPersonalHome => l10n.instanceEnrolNotHome(home),
        EnrolmentRefusal.sameInstallation => l10n.instanceEnrolSame,
        EnrolmentRefusal.notAnInstallation => l10n.instanceEnrolUnreadable,
      };

  Future<void> _enrol() async {
    final home = _home;
    if (home == null) return;
    final l10n = context.l10n;
    final name = _homes.firstWhere((p) => p.ref == home).name;
    setState(() {
      _busy = true;
      _error = _done = null;
    });
    String? done;
    String? error;
    try {
      final enrolment = InstallationEnrolment(widget.api);
      final candidate = await enrolment.inspect(widget.projectRef);
      await enrolment.enrol(home, candidate, accepting: _accepting);
      done = l10n.instanceEnrolDone(name);
    } on EnrolmentRefused catch (e, st) {
      TraceLogger.instance.warn(
        'instance',
        'enrolment refused',
        error: e,
        stackTrace: st,
      );
      error = _refusal(l10n, e, name);
    } on ManagementApiException catch (e, st) {
      TraceLogger.instance.warn(
        'instance',
        'enrolment refused',
        error: e,
        stackTrace: st,
      );
      error = e.unauthorized ? l10n.instanceTokenRefused : e.message;
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'instance',
        'enrolment failed',
        error: e,
        stackTrace: st,
      );
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = done;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final homes = _homes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardText(l10n.instanceEnrolIntro),
        if (homes.isEmpty)
          WizardText(l10n.instanceEnrolNoHome)
        else ...[
          DropdownButtonFormField<String>(
            key: const ValueKey('instance-enrol-home'),
            initialValue: _home,
            decoration: InputDecoration(
              labelText: l10n.instanceEnrolHomeLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in homes)
                DropdownMenuItem(
                  key: ValueKey('instance-enrol-home-${p.ref}'),
                  value: p.ref,
                  child: Text(p.name),
                ),
            ],
            onChanged: _busy || _done != null
                ? null
                : (v) => setState(() {
                    _home = v;
                    _error = null;
                  }),
          ),
          SwitchListTile(
            key: const ValueKey('instance-enrol-accepting'),
            value: _accepting,
            title: Text(l10n.instanceEnrolAccepting),
            onChanged: _busy || _done != null
                ? null
                : (v) => setState(() => _accepting = v),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('instance-enrol-run'),
            onPressed: _busy || _home == null || _done != null ? null : _enrol,
            icon: const Icon(Icons.how_to_reg_outlined),
            label: Text(l10n.instanceEnrolRun),
          ),
        ],
        if (_done case final done?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: WizardText(
              done,
              key: const ValueKey('instance-enrol-done'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Card(
              key: const ValueKey('instance-enrol-error'),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: AppSpacing.mdAll, child: Text(error)),
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
