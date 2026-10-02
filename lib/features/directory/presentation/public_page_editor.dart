// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';
import 'public_workspace_view.dart';

class PublicPageEditor extends ConsumerStatefulWidget {
  const PublicPageEditor({super.key});
  @override
  ConsumerState<PublicPageEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<PublicPageEditor> {
  static const _fields = [
    'description',
    'address',
    'email',
    'phone',
    'website',
    'image_url',
    'plan_url',
    'plans',
    'latitude',
    'longitude',
  ];
  final _controllers = {
    for (final field in _fields) field: TextEditingController(),
  };
  String? _workspace, _account;
  bool _loading = false;
  String _host = 'association';
  bool _published = false, _loaded = false, _busy = false, _failed = false;

  /// #2086 — the inherited fields that still follow the workspace
  /// information; editing one makes it the owner's override.
  Set<String> _following = {};
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String workspace) async {
    if (!mounted) return;
    final account = _account;
    _loading = true;
    final l = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'load public workspace page failed',
      errorText:
          l?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () async {
        final page = await ref
            .read(publicationActionsProvider)
            .ownPage(workspace);
        if (!mounted || _workspace != workspace || _account != account) return;
        final doc = Map<String, dynamic>.from(page['document'] as Map);
        setState(() {
          for (final field in _fields) {
            _controllers[field]!.text = doc[field] as String? ?? '';
          }
          _host = doc['host_type'] as String? ?? 'association';
          _published = page['published'] == true;
          _following = publicFollowing(page);
          _loaded = true;
        });
      },
    );
    if (mounted && _workspace == workspace && _account == account) {
      setState(() {
        _failed = !ok;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_loaded) return;
    final workspace = _workspace;
    final account = _account;
    if (workspace == null) return;
    final l = AppLocalizations.of(context);
    Map<String, dynamic>? preview;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'publish workspace page failed',
      errorText:
          l?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () async {
        preview = await ref.read(publicationActionsProvider).savePage(
          workspace,
          {
            'host_type': _host,
            for (final entry in _controllers.entries)
              entry.key: entry.value.text.trim(),
          },
          _published,
          following: _following,
        );
      },
    );
    if (!mounted || _workspace != workspace || _account != account) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(publicDirectoryProvider);
      ref.invalidate(currentWorkspaceProvider);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicWorkspaceView(
            workspace: PublicWorkspace(workspace, '', '', preview!),
            preview: true,
          ),
        ),
      );
    }
  }

  /// #2086 — back to the workspace information: [fields], or every
  /// inherited field when null. Only those fields are refreshed, so an
  /// unsaved edit elsewhere on the page survives.
  Future<void> _reset(Set<String>? fields) async {
    if (_busy || !_loaded) return;
    final workspace = _workspace;
    final account = _account;
    if (workspace == null) return;
    final l = AppLocalizations.of(context);
    if (fields == null && !await _confirmResetAll(l)) return;
    if (!mounted) return;
    Map<String, dynamic>? page;
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'directory',
      message: 'reset public page to workspace information failed',
      errorText:
          l?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () async {
        page = await ref
            .read(publicationActionsProvider)
            .resetPage(workspace, fields: fields);
      },
    );
    if (!mounted || _workspace != workspace || _account != account) return;
    setState(() {
      _busy = false;
      final answer = page;
      if (answer == null) return;
      final doc = Map<String, dynamic>.from(answer['document'] as Map);
      for (final field in fields ?? publicInheritedFields.toSet()) {
        if (field == 'host_type') {
          _host = doc['host_type'] as String? ?? _host;
        } else {
          _controllers[field]?.text = doc[field] as String? ?? '';
        }
      }
      _following = publicFollowing(answer);
    });
    if (page != null) ref.invalidate(publicDirectoryProvider);
  }

  Future<bool> _confirmResetAll(AppLocalizations? l) async {
    final material = MaterialLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l?.portalResetAll ??
              'Reset all public data to workspace information',
        ),
        content: Text(
          l?.portalResetAllBody ??
              'The public values of every field that has workspace '
                  'information are replaced by it. Fields without a '
                  'workspace counterpart keep what you typed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('public-page-reset-all-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l?.portalResetAllConfirm ?? 'Reset'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _override(String field) {
    if (_following.contains(field)) {
      setState(() => _following = {..._following}..remove(field));
    }
  }

  Widget _inheritance(String field, AppLocalizations? l) => _InheritedStatus(
    key: ValueKey('public-page-inherit-$field'),
    following: _following.contains(field),
    busy: _busy,
    l: l,
    onReset: () => _reset({field}),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final owner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;
    final account = ref.watch(authStateProvider).value;
    if (workspace?.id != _workspace || account != _account) {
      _account = account;
      _workspace = workspace?.id;
      _loaded = false;
      _failed = false;
      _loading = false;
      _busy = false;
      for (final c in _controllers.values) {
        c.clear();
      }
    }
    if (_workspace != null && owner && !_loaded && !_failed && !_loading) {
      _loading = true;
      Future.microtask(() => _load(workspace!.id));
    }
    final labels = {
      'description': l?.portalDescription ?? 'Description',
      'address': l?.portalAddress ?? 'Public address',
      'email': l?.portalEmail ?? 'Public email',
      'phone': l?.portalPhone ?? 'Public phone',
      'website': l?.portalWebsite ?? 'Website',
      'image_url': l?.portalImage ?? 'Identity image URL',
      'plan_url': l?.portalPublicPlan ?? 'Public floor plan',
      'plans': l?.portalPlans ?? 'Plans and prices',
      'latitude': l?.portalLatitude ?? 'Latitude',
      'longitude': l?.portalLongitude ?? 'Longitude',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l?.portalPublication ?? 'Public workspace page'),
      ),
      body: !owner
          ? const SizedBox.shrink()
          : !_loaded
          ? (_failed
                ? Center(
                    child: TextButton(
                      onPressed: () => _load(_workspace!),
                      child: Text(l?.commonRetry ?? 'Try again'),
                    ),
                  )
                : const LoadingView())
          : ListView(
              padding: AppSpacing.mdAll,
              children: [
                SwitchListTile(
                  value: _published,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _published = v),
                  title: Text(
                    l?.portalPublished ?? 'Visible in the public directory',
                  ),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('public-page-host-$_host'),
                  initialValue: _host,
                  items: [
                    for (final type in ['association', 'company', 'person'])
                      DropdownMenuItem(
                        value: type,
                        child: Text(switch (type) {
                          'association' =>
                            l?.portalAssociation ?? 'Association',
                          'company' => l?.portalCompany ?? 'Company',
                          _ => l?.portalPerson ?? 'Private host',
                        }),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null || v == _host) return;
                          _override('host_type');
                          setState(() => _host = v);
                        },
                ),
                _inheritance('host_type', l),
                for (final field in _fields)
                  Padding(
                    padding: AppSpacing.smAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _controllers[field],
                          enabled: !_busy,
                          maxLength: 4000,
                          maxLines: field == 'description' || field == 'plans'
                              ? 3
                              : 1,
                          onChanged: (_) => _override(field),
                          decoration: InputDecoration(
                            labelText: labels[field],
                          ),
                        ),
                        if (publicInheritedFields.contains(field))
                          _inheritance(field, l),
                      ],
                    ),
                  ),
                Padding(
                  padding: AppSpacing.smAll,
                  child: OutlinedButton(
                    key: const ValueKey('public-page-reset-all'),
                    onPressed: _busy ? null : () => _reset(null),
                    child: Text(
                      l?.portalResetAll ??
                          'Reset all public data to workspace information',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    l?.portalSavePreview ??
                        'Save and preview the external view',
                  ),
                ),
              ],
            ),
    );
  }
}

/// #2086 — whether an inherited public field follows the workspace
/// information or holds the owner's own value, with the way back.
class _InheritedStatus extends StatelessWidget {
  const _InheritedStatus({
    super.key,
    required this.following,
    required this.busy,
    required this.l,
    required this.onReset,
  });
  final bool following, busy;
  final AppLocalizations? l;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final status = following
        ? l?.portalFollowsWorkspace ?? 'From workspace information'
        : l?.portalCustomised ?? 'Customised';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Icon(
          following ? Icons.link : Icons.edit_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Text(status, style: Theme.of(context).textTheme.bodySmall),
        if (!following)
          TextButton(
            onPressed: busy ? null : onReset,
            child: Text(
              l?.portalUseWorkspaceInfo ?? 'Use workspace information',
            ),
          ),
      ],
    );
  }
}
