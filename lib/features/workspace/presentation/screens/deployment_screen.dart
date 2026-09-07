// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/deployment.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/deployment_providers.dart';
import '../../providers/workspace_providers.dart';

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
    final repo = ref.read(deploymentRepositoryProvider);
    final registry = await repo.entities();
    final journal = await repo.journal(workspace.pairId);
    if (!mounted) return;
    setState(() {
      _registry = registry;
      _journal = journal;
    });
  }

  Workspace? _twinOf(Workspace workspace) => (ref
              .watch(myWorkspacesProvider)
              .value ??
          const <Workspace>[])
      .where((w) => w.pairId == workspace.pairId && w.id != workspace.id)
      .firstOrNull;

  void _toggle(String key, bool on) {
    setState(() {
      if (on) {
        _selected.addAll(withRequirements([key], _registry ?? const []));
      } else {
        _selected.remove(key);
        // Nothing may stay selected that required what just left.
        _selected.removeWhere((k) => (_registry ?? const [])
            .firstWhere((e) => e.key == k)
            .requires
            .contains(key));
      }
    });
  }

  Future<void> _previewAndDeploy(Workspace from, Workspace to) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(deploymentRepositoryProvider);
    final entities = _selected.toList()..sort();
    setState(() => _busy = true);
    DeploymentPreview? preview;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment preview failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        preview = await repo.preview(from.id, to.id, entities);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok || preview == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PreviewSheet(
        preview: preview!,
        target: to,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final deployed = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => repo.deploy(from.id, to.id, entities),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!deployed) return;
    AppSnack.success(
        context, l10n?.deploymentDone ?? 'Deployed. The journal has it.');
    ref.invalidate(myWorkspacesProvider);
    await _load(from);
  }

  Future<void> _rollback(Workspace from, Deployment deployment) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'deployment rollback failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(deploymentRepositoryProvider).rollback(deployment.id),
    );
    if (!ok || !mounted) return;
    AppSnack.success(
        context, l10n?.deploymentRolledBack ?? 'Rolled back.');
    await _load(from);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final title = Text(l10n?.deploymentTitle ?? 'Deployment');
    if (workspace == null) {
      return Scaffold(appBar: AppBar(title: title), body: const LoadingView());
    }
    if (!_loaded) {
      _loaded = true;
      Future<void>.microtask(() => _load(workspace));
    }
    final twin = _twinOf(workspace);
    final perms = ref.watch(myPermissionsProvider);
    final toProd = workspace.isDevelopment;
    final allowed = toProd
        ? perms.contains(WorkspacePermission.deployToProd)
        : perms.contains(WorkspacePermission.deployToDev);
    final registry = _registry;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: title),
      body: registry == null
          ? const LoadingView()
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  toProd
                      ? (l10n?.deploymentIntroToProd ??
                          'You stand on the development side. What you tick '
                              'below is deployed to the production twin, after '
                              'a preview of what changes.')
                      : (l10n?.deploymentIntroToDev ??
                          'You stand on the production side. What you tick '
                              'below is deployed to the development twin, '
                              'after a preview of what changes.'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (twin == null)
                  InlineBanner(
                    key: const ValueKey('deploy-no-twin'),
                    icon: Icons.info_outline,
                    text: l10n?.deploymentNoTwin ??
                        'This workspace has no twin you are a member of.',
                  ),
                if (!allowed)
                  InlineBanner(
                    key: const ValueKey('deploy-not-allowed'),
                    icon: Icons.lock_outline,
                    text: toProd
                        ? (l10n?.deploymentNeedsProdPermission ??
                            'Deploying to production needs the "Deploy to '
                                'production" permission.')
                        : (l10n?.deploymentNeedsDevPermission ??
                            'Deploying to development needs the "Deploy to '
                                'development" permission.'),
                  ),
                for (final entity in registry)
                  CheckboxListTile(
                    key: ValueKey('deploy-entity-${entity.key}'),
                    value: _selected.contains(entity.key),
                    title: Text(deploymentEntityName(l10n, entity.key)),
                    subtitle: Text([
                      entity.isMasterData
                          ? (l10n?.deploymentKindMasterData ?? 'Master data')
                          : (l10n?.deploymentKindConfiguration ??
                              'Configuration'),
                      if (entity.requires.isNotEmpty)
                        '${l10n?.deploymentRequires ?? 'needs'} '
                            '${entity.requires.map((r) => deploymentEntityName(l10n, r)).join(', ')}',
                    ].join(' · ')),
                    onChanged: _busy || twin == null || !allowed
                        ? null
                        : (v) => _toggle(entity.key, v ?? false),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('deploy-preview'),
                  onPressed: _busy ||
                          twin == null ||
                          !allowed ||
                          _selected.isEmpty
                      ? null
                      : () => _previewAndDeploy(workspace, twin),
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: Text(toProd
                      ? (l10n?.deploymentToProd ?? 'Deploy to PROD…')
                      : (l10n?.deploymentToDev ?? 'Deploy to DEV…')),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n?.deploymentJournal ?? 'Journal',
                    style: theme.textTheme.titleSmall),
                if (_journal.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      l10n?.deploymentJournalEmpty ?? 'Nothing deployed yet.',
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
                      '${d.direction == DeploymentDirection.devToProd ? (l10n?.deploymentDirectionToProd ?? 'To production') : (l10n?.deploymentDirectionToDev ?? 'To development')}'
                      ' · ${d.entities.map((e) => deploymentEntityName(l10n, e)).join(', ')}',
                    ),
                    subtitle: Text([
                      if (d.actorName.isNotEmpty) d.actorName,
                      if (d.createdAt != null)
                        d.createdAt!.toIso8601String().substring(0, 16).replaceFirst('T', ' '),
                      if (d.isRolledBack)
                        l10n?.deploymentRolledBackLabel ?? 'rolled back',
                    ].join(' · ')),
                    trailing: index == 0 && !d.isRolledBack && allowed
                        ? TextButton(
                            key: ValueKey('deploy-rollback-${d.id}'),
                            onPressed: _busy
                                ? null
                                : () => _rollback(workspace, d),
                            child: Text(
                                l10n?.deploymentRollback ?? 'Roll back'),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.preview, required this.target});

  final DeploymentPreview preview;
  final Workspace target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.direction == DeploymentDirection.devToProd
                  ? (l10n?.deploymentPreviewToProd ??
                      'What changes on the production side')
                  : (l10n?.deploymentPreviewToDev ??
                      'What changes on the development side'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final e in preview.entries)
              ListTile(
                key: ValueKey('deploy-preview-${e.key}'),
                dense: true,
                title: Text(deploymentEntityName(l10n, e.key)),
                subtitle: Text(e.isNoop
                    ? (l10n?.deploymentNoChange ?? 'No change')
                    : '+${e.added} · ~${e.changed} · −${e.removed}'),
              ),
            if (preview.isNoop)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n?.deploymentNothingToDo ??
                      'The two sides already agree on these entities.',
                  key: const ValueKey('deploy-preview-noop'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n?.commonCancel ?? 'Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('deploy-confirm'),
                  onPressed: preview.isNoop
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: Text(l10n?.deploymentConfirm ?? 'Deploy'),
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
String deploymentEntityName(AppLocalizations? l10n, String key) =>
    switch (key) {
      'identity' => l10n?.deployEntityIdentity ?? 'Identity & legal',
      'vat' => l10n?.deployEntityVat ?? 'VAT',
      'tariffs' => l10n?.deployEntityTariffs ?? 'Tariffs',
      'services' => l10n?.deployEntityServices ?? 'Services',
      'packages' => l10n?.deployEntityPackages ?? 'Packages',
      'accessories' => l10n?.deployEntityAccessories ?? 'Accessories',
      'sites' => l10n?.deployEntitySites ?? 'Sites',
      'booking_rules' => l10n?.deployEntityBookingRules ?? 'Booking rules',
      'validation_rules' =>
        l10n?.deployEntityValidationRules ?? 'Validation rules',
      'roles' => l10n?.deployEntityRoles ?? 'Role matrix',
      'reminders' => l10n?.deployEntityReminders ?? 'Reminder rules',
      'document_design' =>
        l10n?.deployEntityDocumentDesign ?? 'Document designs',
      'document_links' =>
        l10n?.deployEntityDocumentLinks ?? 'Document links',
      'closure_days' => l10n?.deployEntityClosureDays ?? 'Closure days',
      'invitations' => l10n?.deployEntityInvitations ?? 'Invitation templates',
      'features' => l10n?.deployEntityFeatures ?? 'Features',
      _ => key,
    };
