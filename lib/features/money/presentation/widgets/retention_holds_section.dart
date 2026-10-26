// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/vat/retention.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../application/retention_holds.dart';
import '../../domain/retention_hold.dart';
import '../../providers/book_profile_providers.dart';
import 'retention_clocks_tile.dart';

/// The legal holds of the space: what each keeps, since when and why, and
/// for someone who manages billing, placing one and releasing it with a
/// reason. A hold keeps its records past every retention clock.
class RetentionHoldsSection extends ConsumerWidget {
  const RetentionHoldsSection({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final loaded = ref.watch(retentionHoldsProvider);
    final holds = [
      for (final h in loaded.value ?? const <RetentionHold>[])
        if (h.active) h,
    ];
    final scope = ref.watch(accountingSystemsScopeProvider);
    final sites = scope.issuers;
    final canManage = scope.permissions.contains(
      WorkspacePermission.manageBilling.wireName,
    );
    final day = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      key: const ValueKey('retention-holds'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.retentionHoldsTitle, style: theme.textTheme.titleSmall),
        // A refused or failed read is said as such, never as "no hold".
        if (loaded case AsyncError(:final error))
          Text(
            knownRefusalText(l10n, error) ?? l10n.retentionHoldsLoadFailed,
            key: const ValueKey('retention-holds-failed'),
            style: theme.textTheme.bodySmall,
          )
        else if (!loaded.hasValue)
          const LinearProgressIndicator()
        else if (holds.isEmpty)
          Text(l10n.retentionHoldsEmpty, style: theme.textTheme.bodySmall),
        for (final h in holds)
          ListTile(
            key: ValueKey('retention-hold-${h.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(h.reason),
            subtitle: Text(
              l10n.retentionHoldSince(
                h.docClass == null
                    ? l10n.retentionHoldEveryClass
                    : retentionClassName(l10n, h.docClass!),
                h.issuerSiteId == null
                    ? l10n.retentionHoldEveryIssuer
                    : sites[h.issuerSiteId] ?? h.issuerSiteId!,
                day.format(h.placedAt),
              ),
            ),
            trailing: canManage
                ? TextButton(
                    key: ValueKey('retention-hold-release-${h.id}'),
                    onPressed: () => _release(context, ref, h),
                    child: Text(l10n.retentionHoldRelease),
                  )
                : null,
          ),
        if (canManage)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('retention-hold-place'),
              icon: const Icon(Icons.lock_clock_outlined),
              label: Text(l10n.retentionHoldPlace),
              onPressed: () => _place(context, ref, sites),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// The sentence for a hold the server refused to place or release.
  String _refused(AppLocalizations l10n, Object error) =>
      knownRefusalText(l10n, error) ?? l10n.retentionHoldSaveFailed;

  Future<void> _place(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> sites,
  ) async {
    final l10n = context.l10n;
    final fields = FormControllers();
    String? docClass;
    String? issuer;
    final placed = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.retentionHoldPlace,
        submitLabel: l10n.retentionHoldPlace,
        submitKey: const ValueKey('retention-hold-save'),
        onDispose: fields.dispose,
        validate: () => retentionHoldReasonValid(fields.text('reason'))
            ? const {}
            : {'reason': l10n.retentionHoldReasonMissing(retentionHoldReasonMax)},
        onSubmit: () async {
          try {
            final outcome = await ref
                .read(retentionHoldCommandsProvider)
                .place(
                  workspaceId: workspaceId,
                  issuerSiteId: issuer,
                  docClass: docClass,
                  reason: fields.text('reason'),
                );
            return outcome == RetentionHoldOutcome.done
                ? null
                : l10n.retentionHoldReasonMissing(retentionHoldReasonMax);
          } on Object catch (e, st) {
            TraceLogger.instance.error(
              'money',
              'place retention hold failed',
              error: e,
              stackTrace: st,
            );
            return _refused(l10n, e);
          }
        },
        builder: (context, refresh) => [
          DropdownButtonFormField<String?>(
            key: const ValueKey('retention-hold-class'),
            initialValue: docClass,
            decoration: InputDecoration(labelText: l10n.retentionHoldClass),
            items: [
              DropdownMenuItem(child: Text(l10n.retentionHoldEveryClass)),
              for (final c in retentionClasses)
                DropdownMenuItem(
                  value: c,
                  child: Text(retentionClassName(l10n, c)),
                ),
            ],
            onChanged: (v) => docClass = v,
          ),
          const FormGap(),
          DropdownButtonFormField<String?>(
            key: const ValueKey('retention-hold-issuer'),
            initialValue: issuer,
            decoration: InputDecoration(labelText: l10n.retentionHoldIssuer),
            items: [
              DropdownMenuItem(child: Text(l10n.retentionHoldEveryIssuer)),
              for (final s in sites.entries)
                DropdownMenuItem(value: s.key, child: Text(s.value)),
            ],
            onChanged: (v) => issuer = v,
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('retention-hold-reason'),
            controller: fields['reason'],
            fieldKey: 'reason',
            label: l10n.retentionHoldReason,
            helper: l10n.retentionHoldReasonHelper,
            maxLines: 3,
            maxLength: retentionHoldReasonMax,
          ),
        ],
      ),
    );
    if (!placed || !context.mounted) return;
    ref.invalidate(retentionHoldsProvider);
    AppSnack.success(context, l10n.retentionHoldPlaced);
  }

  Future<void> _release(
    BuildContext context,
    WidgetRef ref,
    RetentionHold hold,
  ) async {
    final l10n = context.l10n;
    final fields = FormControllers();
    final released = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.retentionHoldReleaseTitle,
        submitLabel: l10n.retentionHoldRelease,
        submitKey: const ValueKey('retention-hold-release-save'),
        onDispose: fields.dispose,
        validate: () => retentionHoldReasonValid(fields.text('reason'))
            ? const {}
            : {'reason': l10n.retentionHoldReasonMissing(retentionHoldReasonMax)},
        onSubmit: () async {
          try {
            final outcome = await ref
                .read(retentionHoldCommandsProvider)
                .release(hold.id, fields.text('reason'));
            return outcome == RetentionHoldOutcome.done
                ? null
                : l10n.retentionHoldReasonMissing(retentionHoldReasonMax);
          } on Object catch (e, st) {
            TraceLogger.instance.error(
              'money',
              'release retention hold failed',
              error: e,
              stackTrace: st,
            );
            return _refused(l10n, e);
          }
        },
        builder: (context, refresh) => [
          Text(hold.reason),
          const FormGap(),
          AppTextField(
            key: const ValueKey('retention-hold-release-reason'),
            controller: fields['reason'],
            fieldKey: 'reason',
            label: l10n.retentionHoldReleaseReason,
            maxLines: 3,
            maxLength: retentionHoldReasonMax,
          ),
        ],
      ),
    );
    if (!released || !context.mounted) return;
    ref.invalidate(retentionHoldsProvider);
    AppSnack.success(context, l10n.retentionHoldReleased);
  }
}
