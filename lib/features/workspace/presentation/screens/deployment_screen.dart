// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/deploy_configuration.dart';
import '../../domain/deployment.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/deployment_providers.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';

/// #990 — the deployment between the two sides of a pair.
///
/// The direction is the side you stand on: from the dev the button
/// says *Deploy to PROD*, from the prod *Deploy to DEV*. The list is
/// the server's entity registry; ticking one ticks what it requires.
/// Nothing moves before a preview said what would change, and every
/// deployment lands in the journal with a way back.
class DeploymentScreen extends ConsumerStatefulWidget {
  const DeploymentScreen({super.key});

  @override
  ConsumerState<DeploymentScreen> createState() => _DeploymentScreenState();
}

class _DeploymentScreenState extends ConsumerState<DeploymentScreen> {
  List<DeployableEntity>? _registry;
  List<Deployment> _journal = const [];
  final Set<String> _selected = {};
  bool _busy = false;
  bool _loaded = false;

  Future<void> _load(Workspace workspace) async {
    final board = await ref.read(deploymentsProvider).board(workspace.pairId);
    if (!mounted) return;
    setState(() {
      _registry = board.registry;
      _journal = board.journal;
    });
  }

  Workspace? _twinOf(Workspace workspace) => (ref
              .watch(myWorkspacesProvider)
              .value ??
          const <Workspace>[])
      .where((w) => w.pairId == workspace.pairId && w.id != workspace.id)
      .firstOrNull;

  void _toggle(String key, bool on) {
    // #1449 — the tick rule is application/deploy_configuration.dart's:
    // ticking one ticks what it requires, unticking one unticks
    // everything that required it, transitively.
    final next = selectionAfter(
      selected: _selected,
      registry: _registry ?? const [],
      key: key,
      on: on,
    );
    setState(() {
      _selected
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _previewAndDeploy(Workspace from, Workspace to) async {
    final l10n = context.l10n;
    final deployments = ref.read(deploymentsProvider);
    setState(() => _busy = true);
    // #1449 — the previewed deployment carries the entities it was
    // computed for, so the deploy below writes what was SHOWN and not
    // whatever the ticks became meanwhile.
    PreviewedDeployment? previewed;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment preview failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        previewed = await deployments.examine(
          fromWorkspaceId: from.id,
          toWorkspaceId: to.id,
          selection: _selected,
          registry: _registry ?? const [],
        );
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok || previewed == null) return;
    final entities = previewed!.entities;
    final confirmed = await showAppSheet<bool>(
      context: context,
      showDragHandle: true,
      // #1006 — seventeen entities do not fit a phone: the sheet takes
      // the height it needs, its list scrolls, the buttons stay put.
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (context) => _PreviewSheet(
        preview: previewed!.preview,
        target: to,
        notApplicable: _selected.contains('features')
            ? featuresLostInCountry(
                resolveEnabledFeatures(from.featureFlags),
                to.countryCode,
              )
            : const [],
      ),
    );
    if (confirmed != true || !mounted) return;
    // #1006 — the last word: which side is written, and that it is this one.
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(to.isDevelopment
            ? (l10n.deploymentConfirmTitleDev)
            : (l10n.deploymentConfirmTitleProd)),
        content: Text(
          '${l10n.deploymentConfirmBody}\n\n'
          '${entities.map((e) => _deploymentEntityName(l10n, e)).join(', ')}',
        ),
        actions: [
          TextButton(
            key: const ValueKey('deploy-final-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('deploy-final-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deploymentConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final deployed = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment failed',
      errorText: l10n.workspaceGenericError,
      action: () => deployments.apply(previewed!),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!deployed) return;
    AppSnack.success(
        context, l10n.deploymentDone);
    ref.invalidate(myWorkspacesProvider);
    await _load(from);
  }

  Future<void> _rollback(Workspace from, Deployment deployment) async {
    final l10n = context.l10n;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment rollback failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(deploymentsProvider).rollBack(deployment.id),
    );
    if (!ok || !mounted) return;
    AppSnack.success(
        context, l10n.deploymentRolledBack);
    await _load(from);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final title = Text(l10n.deploymentTitle);
    if (workspace == null) {
      return Scaffold(appBar: AppBar(title: title), body: const LoadingView());
    }
    if (!_loaded) {
      _loaded = true;
      unawaited(Future<void>.microtask(() => _load(workspace)));
    }
    final twin = _twinOf(workspace);
    final perms = ref.watch(myPermissionsProvider);
    // #1006 — the deployment is always INTO the side you stand on: the
    // twin is the source, this workspace the target. Nothing can be
    // pushed onto the other side by mistake.
    final toProd = !workspace.isDevelopment;
    final allowed = toProd
        ? perms.contains(WorkspacePermission.deployToProd)
        : perms.contains(WorkspacePermission.deployToDev);
    final from = twin;
    final to = workspace;
    final registry = _registry;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: title,
        // #1022 — the screen's own symbol: a deployment writes
        // the side you stand on, and the guide says so first.
        actions: [
          HelpDot(
            l10n.helpTopicDeployment,
            anchor: HelpAnchor.advancedDeploy,
          ),
        ],
      ),
      body: registry == null
          ? const LoadingView()
          : ListView(
              key: const ValueKey('deploy-list'),
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  workspace.isDevelopment
                      ? (l10n.deploymentIntroFromProd)
                      : (l10n.deploymentIntroFromDev),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (twin == null)
                  InlineBanner(
                    key: const ValueKey('deploy-no-twin'),
                    icon: Icons.info_outline,
                    text: l10n.deploymentNoTwin,
                  ),
                if (!allowed)
                  InlineBanner(
                    key: const ValueKey('deploy-not-allowed'),
                    icon: Icons.lock_outline,
                    text: toProd
                        ? (l10n.deploymentNeedsProdPermission)
                        : (l10n.deploymentNeedsDevPermission),
                  ),
                // #998 — grouped: configuration, master data, reports.
                for (final (kind, label) in [
                  ('configuration',
                      l10n.deploymentKindConfiguration),
                  ('master_data',
                      l10n.deploymentKindMasterData),
                  ('reports', l10n.deploymentKindReports),
                ])
                  if (registry.any((e) => e.kind == kind)) ...[
                    Padding(
                      key: ValueKey('deploy-group-$kind'),
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(label, style: theme.textTheme.titleSmall),
                    ),
                    for (final entity in registry.where((e) => e.kind == kind))
                      CheckboxListTile(
                        key: ValueKey('deploy-entity-${entity.key}'),
                        value: _selected.contains(entity.key),
                        title: Text(_deploymentEntityName(l10n, entity.key)),
                        subtitle: entity.requires.isEmpty
                            ? null
                            : Text(
                                '${l10n.deploymentRequires} '
                                '${entity.requires.map((r) => _deploymentEntityName(l10n, r)).join(', ')}'),
                        onChanged: _busy || twin == null || !allowed
                            ? null
                            : (v) => _toggle(entity.key, v ?? false),
                      ),
                  ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('deploy-preview'),
                  onPressed: _busy ||
                          from == null ||
                          !allowed ||
                          _selected.isEmpty
                      ? null
                      : () => _previewAndDeploy(from, to),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(workspace.isDevelopment
                      ? (l10n.deploymentPullFromProd)
                      : (l10n.deploymentPullFromDev)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.deploymentJournal,
                  style: theme.textTheme.titleSmall,
                ),
                if (_journal.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      l10n.deploymentJournalEmpty,
                      key: const ValueKey('deploy-journal-empty'),
                    ),
                  ),
                for (final (index, d) in _journal.indexed)
                  ListTile(
                    key: ValueKey('deploy-journal-${d.id}'),
                    leading: Icon(d.direction == DeploymentDirection.devToProd
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    title: Text(
                      '${d.direction == DeploymentDirection.devToProd ? (l10n.deploymentDirectionToProd) : (l10n.deploymentDirectionToDev)}'
                      ' · ${d.entities.map((e) => _deploymentEntityName(l10n, e)).join(', ')}',
                    ),
                    subtitle: Text([
                      if (d.actorName.isNotEmpty) d.actorName,
                      if (d.createdAt != null)
                        // #2352 — the reader's clock, never the raw UTC instant.
                        appFormatOf(context).dateTime(d.createdAt!),
                      if (d.isRolledBack)
                        l10n.deploymentRolledBackLabel,
                    ].join(' · ')),
                    trailing: index == 0 && !d.isRolledBack && allowed
                        ? TextButton(
                            key: ValueKey('deploy-rollback-${d.id}'),
                            onPressed: _busy
                                ? null
                                : () => _rollback(workspace, d),
                            child: Text(
                                l10n.deploymentRollback),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    required this.preview,
    required this.target,
    this.notApplicable = const [],
  });

  final DeploymentPreview preview;
  final Workspace target;

  /// #2454 — features the deployment switches on that the target's country
  /// does not offer: stored as set, not applicable there.
  final List<WorkspaceFeature> notApplicable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.direction == DeploymentDirection.devToProd
                  ? (l10n.deploymentPreviewToProd)
                  : (l10n.deploymentPreviewToDev),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                key: const ValueKey('deploy-preview-list'),
                shrinkWrap: true,
                children: [
                  for (final e in preview.entries)
                    ListTile(
                      key: ValueKey('deploy-preview-${e.key}'),
                      dense: true,
                      title: Text(_deploymentEntityName(l10n, e.key)),
                      subtitle: Text(e.isNoop
                          ? (l10n.deploymentNoChange)
                          : '+${e.added} · ~${e.changed} · −${e.removed}'),
                    ),
                  if (notApplicable.isNotEmpty)
                    InlineBanner(
                      key: const ValueKey('deploy-preview-not-applicable'),
                      icon: Icons.public_off_outlined,
                      text: l10n.deploymentFeaturesNotApplicable(
                        target.countryCode,
                        notApplicable.map((f) => featureName(l10n, f)).join(', '),
                      ),
                    ),
                  if (preview.isNoop)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        l10n.deploymentNothingToDo,
                        key: const ValueKey('deploy-preview-noop'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('deployment-cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('deploy-confirm'),
                  onPressed: preview.isNoop
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: Text(l10n.deploymentConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// #988 — the entity's name in the reader's language.
String _deploymentEntityName(AppLocalizations l10n, String key) =>
    switch (key) {
      'identity' => l10n.deployEntityIdentity,
      'vat' => l10n.deployEntityVat,
      'tariffs' => l10n.deployEntityTariffs,
      'services' => l10n.deployEntityServices,
      'packages' => l10n.deployEntityPackages,
      'accessories' => l10n.deployEntityAccessories,
      'sites' => l10n.deployEntitySites,
      'floor_plan' =>
        l10n.deployEntityFloorPlan,
      'booking_rules' => l10n.deployEntityBookingRules,
      'validation_rules' =>
        l10n.deployEntityValidationRules,
      'roles' => l10n.deployEntityRoles,
      'payment_instructions' =>
        l10n.deployEntityPaymentInstructions,
      'reminders' => l10n.deployEntityReminders,
      'document_design' =>
        l10n.deployEntityDocumentDesign,
      'document_links' =>
        l10n.deployEntityDocumentLinks,
      'closure_days' => l10n.deployEntityClosureDays,
      'invitations' => l10n.deployEntityInvitations,
      'features' => l10n.deployEntityFeatures,
      'branding' => l10n.deployEntityBranding,
      'field_definitions' =>
        l10n.deployEntityFieldDefinitions,
      'workspace_roles' =>
        l10n.deployEntityWorkspaceRoles,
      'credit_products' =>
        l10n.deployEntityCreditProducts,
      _ => key,
    };
