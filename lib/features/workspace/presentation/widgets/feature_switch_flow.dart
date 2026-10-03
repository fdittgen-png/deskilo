// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1851 B — what one switch on the Features screen does, from the tap to
// the confirmed row: plan the switch (feature_switch.dart), ask for
// consent when it turns on an experimental feature (naming its stage and
// what comes on with it), write the delta against the flags it was read
// as, and say what really happened — written, changed meanwhile (nothing
// written), unconfirmed, or failed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/feature_switch.dart';
import '../../domain/feature_flags_write.dart';
import '../../domain/feature_lifecycle.dart';
import '../../domain/feature_operation.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';
import 'feature_maturity_badge.dart';
import 'feature_opt_in_dialog.dart';

/// Switches [feature] to [value] for [workspace], whose stored set is
/// [enabled]; [assessments] decide which features ask for consent.
Future<void> switchWorkspaceFeature(
  BuildContext context,
  WidgetRef ref, {
  required Workspace workspace,
  required Set<WorkspaceFeature> enabled,
  required WorkspaceFeature feature,
  required bool value,
  required Map<WorkspaceFeature, FeatureAssessment> assessments,
}) async {
  final l10n = AppLocalizations.of(context);
  // #800 — switching one ON switches on everything it NEEDS.
  //
  // A switch that can be flipped green while the feature stays absent
  // is the worst kind of setting: the owner has configured the thing
  // and the app disagrees, with nothing on screen to explain it.
  // #1851 B — the preview and the exact write it stands for: what comes
  // on with it, which experimental features need a yes, and the
  // read-set the write is conditioned on.
  final plan = planFeatureSwitch(
    raw: enabled,
    feature: feature,
    value: value,
    needsOptIn: (f) => featureNeedsOptIn(f, assessments: assessments),
  );
  final alsoOn = plan.alsoOn;
  if (plan.needsConsent.isNotEmpty &&
      !await confirmExperimentalOptIn(
        context,
        [for (final f in plan.needsConsent) featureName(l10n, f)],
        stages: [
          for (final f in plan.needsConsent)
            featureMaturityLabel(
              l10n,
              featureAssessmentOf(f, assessments: assessments).maturity,
            ),
        ],
        alsoOn: [
          for (final f in alsoOn)
            if (f != feature) featureName(l10n, f),
        ],
      )) {
    return;
  }
  if (!context.mounted) return;
  try {
    await applyFeatureSwitch(ref, workspace: workspace, plan: plan);
  } on FeatureFlagsConflict catch (e, st) {
    // The decision is stale and nothing was written: read the row again
    // and let the owner decide on what is there now.
    TraceLogger.instance.warn(
      'workspace',
      'feature switch conflicted',
      error: e,
      stackTrace: st,
    );
    ref.invalidate(myWorkspacesProvider);
    if (context.mounted) {
      AppSnack.info(
        context,
        l10n?.featureChangedMeanwhile ??
            'The features changed meanwhile, so nothing was written. '
                'Check the list and switch again.',
        replace: true,
      );
    }
    return;
  } on FeatureFlagsUnconfirmed catch (e, st) {
    TraceLogger.instance.warn(
      'workspace',
      'feature switch unconfirmed',
      error: e,
      stackTrace: st,
    );
    if (context.mounted) {
      AppSnack.info(
        context,
        l10n?.featureChangeUnconfirmed ??
            'The change was sent, but the features could not be reloaded '
                'to confirm it. Reopen the screen to see what is set.',
        replace: true,
      );
    }
    return;
  } catch (e, st) {
    TraceLogger.instance.error(
      'workspace',
      'set feature flags failed',
      error: e,
      stackTrace: st,
    );
    if (context.mounted) {
      AppSnack.error(
        context,
        l10n?.processChangeFailed ??
            'The features could not be changed. Nothing was written; '
                'try again.',
      );
    }
    return;
  }
  // Naming what else came on: a cascade nobody sees is a surprise the
  // next time they read the list.
  if (value && alsoOn.isNotEmpty && context.mounted) {
    AppSnack.info(
      context,
      l10n?.featureAlsoEnabled(
            alsoOn.map((f) => featureName(l10n, f)).join(', '),
          ) ??
          'Also switched on: '
              '${alsoOn.map((f) => featureName(l10n, f)).join(', ')}',
      replace: true,
    );
  }
}
