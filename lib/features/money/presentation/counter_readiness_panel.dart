// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4184 (CS1) -- the counter's readiness as an owner reads it, and the counter's settings beside it: for the
// business's country and the case the owner declared, every operation with its outcome, the specification it rests
// on (version, in force since), the proof, and whether a tax professional confirmed it. An unavailable operation says
// why; a country the registry does not name says that nothing is supported. Nothing here is inferred: the outcome is
// the server's, the evidence its registry's. The settings are the registry editor's own (`counter.*`), so the
// declaration, the document channel and the customer rule are changed where every setting is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_till.dart';
import '../providers/till_providers.dart';
import 'till_text.dart';

/// The owner's declaration, in words.
String _tillDeclarationText(AppLocalizations l10n, String declaration) =>
    declaration == 'none' ? l10n.tillDeclarationNone : l10n.tillDeclarationRegister;

/// The readiness of [readiness]'s country, operation by operation.
class CounterReadinessPanel extends StatelessWidget {
  const CounterReadinessPanel({super.key, required this.readiness});

  final TillReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tillReadinessCase(readiness.country, _tillDeclarationText(l10n, readiness.fiscalObligation)),
          key: const ValueKey('counter-readiness-case'),
          style: theme.textTheme.titleSmall,
        ),
        if (readiness.unknownCountry)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(l10n.tillReadinessUnknownCountry(readiness.country), key: const ValueKey('counter-readiness-no-row')),
          ),
        for (final o in readiness.operations) _Operation(operation: o, format: appFormatOf(context)),
        const FormGap(),
        Text(l10n.tillReadinessOffline, key: const ValueKey('counter-readiness-offline'), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Operation extends StatelessWidget {
  const _Operation({required this.operation, required this.format});

  final TillOperation operation;
  final AppFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final o = operation;
    final small = theme.textTheme.bodySmall;
    return Padding(
      key: ValueKey('counter-readiness-${o.operation}'),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tillOperationName(l10n, o.operation), style: theme.textTheme.titleSmall),
              Chip(
                key: ValueKey('counter-readiness-${o.operation}-${o.supported ? 'supported' : 'unavailable'}'),
                avatar: Icon(o.supported ? Icons.check_circle_outline : Icons.block, size: 18),
                label: Text(o.supported ? l10n.tillReadinessSupported : l10n.tillReadinessUnavailable),
              ),
            ],
          ),
          if (!o.supported && o.reason == 'adapter_missing') Text(l10n.tillReadinessAdapterMissing),
          if (!o.supported && o.note.isNotEmpty) Text(o.note),
          if (o.specification.isNotEmpty)
            Text(
              l10n.tillReadinessSpecification(o.specification, o.specificationVersion, _day(o.effectiveFrom)),
              style: small,
            ),
          if (o.evidence.isNotEmpty) Text(l10n.tillReadinessEvidence(o.evidence), style: small),
          Text(o.confirmed ? l10n.tillReadinessConfirmed : l10n.tillReadinessUnconfirmed, style: small),
        ],
      ),
    );
  }

  String _day(String iso) => iso.isEmpty ? iso : format.isoDay(iso);
}

/// Opens the counter's readiness and settings over the till. Closing it reads the readiness again: the declaration
/// may have changed.
Future<void> showCounterReadinessSheet(BuildContext context, {required String workspaceId}) async {
  final container = ProviderScope.containerOf(context);
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ReadinessSheet(workspaceId: workspaceId),
  );
  container.invalidate(tillReadinessProvider(workspaceId));
}

class _ReadinessSheet extends ConsumerWidget {
  const _ReadinessSheet({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ListView(
        key: const ValueKey('counter-readiness-sheet'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.tillReadinessTitle, style: theme.textTheme.titleLarge),
          const FormGap(),
          ref
              .watch(tillReadinessProvider(workspaceId))
              .when(
                loading: () => const LoadingView(),
                error: (e, _) => Text(tillProblemText(l10n, e)),
                data: (readiness) => CounterReadinessPanel(readiness: readiness),
              ),
          const FormGap(),
          Text(l10n.tillReadinessSettings, style: theme.textTheme.titleMedium),
          ref.watch(counterSettingsEditorProvider)(workspaceId),
        ],
      ),
    );
  }
}
