// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/form_scroll.dart';
import '../../../core/ui/kit/page_bar.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/directory_location.dart';
import '../domain/public_workspace.dart';
import '../domain/publication_draft.dart';
import '../providers/directory_providers.dart';
import '../providers/discovery_listing_providers.dart';
import 'directory_pages.dart';
import 'public_facets_editor.dart';
import 'public_offer_preview.dart';
import 'public_page_place.dart';
import 'public_workspace_view.dart';

class PublicPageEditor extends ConsumerStatefulWidget {
  const PublicPageEditor({super.key});
  @override
  ConsumerState<PublicPageEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<PublicPageEditor> {
  static const _fields = publicPageFields;
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

  /// #3553 — the page as it reads back: its kinds and public services.
  PublicWorkspace? _offer;
  PublicationDraft? _draft;

  /// #4409 — the facets as edited, from [_draft].
  final _facetChanges = ValueNotifier<PublicationDraft>(
    const PublicationDraft(),
  );
  final _hoursNote = TextEditingController();

  /// #3689 — the stored place, kept in the draft so every save carries it.
  final _place = ValueNotifier<DirectoryLocation?>(null);
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _place.dispose();
    _facetChanges.dispose();
    _hoursNote.dispose();
    super.dispose();
  }

  Future<void> _load(String workspace) async {
    if (!mounted) return;
    final account = _account;
    _loading = true;
    final l = context.l10n;
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'load public workspace page failed',
      errorText:
          l.portalActionFailed,
      action: () async {
        final page = await ref
            .read(publicationActionsProvider)
            .ownPage(workspace);
        if (!mounted || _workspace != workspace || _account != account) return;
        final draft = page.draft;
        setState(() {
          for (final field in _fields) {
            _controllers[field]!.text = draft.text(field) ?? '';
          }
          _draft = draft;
          _host = draft.hostType ?? 'association';
          _place.value = draft.place;
          _published = page.published;
          _following = page.following;
          _offer = page.offer;
          _facetChanges.value = draft;
          _hoursNote.text = _offer?.openingHours?.note ?? '';
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
    final l = context.l10n;
    PublicWorkspace? preview;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'publish workspace page failed',
      errorText:
          l.portalActionFailed,
      action: () async {
        preview = await ref.read(publicationActionsProvider).savePage(
          workspace,
          _draft!.diff(
            _facetChanges.value
                .copyWith(
                  hostType: _host,
                  texts: {
                    for (final entry in _controllers.entries)
                      entry.key: entry.value.text.trim(),
                  },
                )
                .withPlace(_place.value),
          ),
          following: _following,
          published: _published,
        );
      },
    );
    if (!mounted || _workspace != workspace || _account != account) return;
    setState(() => _busy = false);
    final saved = preview;
    if (ok && saved != null) {
      _draft = PublicationDraft.fromDocument(saved.document);
      _offer = saved;
      _facetChanges.value = _draft!;
      ref.invalidate(discoveryListingProvider);
      await publicWorkspacePage.open<void>(
        context,
        PublicWorkspaceView(workspace: saved, preview: true),
      );
      // Refresh the publication flag after the routed preview returns, so a
      // workspace redirect cannot replace the push while it carries its page.
      if (mounted && _workspace == workspace && _account == account) {
        ref.invalidate(currentWorkspaceProvider);
      }
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
    final l = context.l10n;
    if (fields == null && !await _confirmResetAll(l)) return;
    if (!mounted) return;
    OwnPublicPage? page;
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'directory',
      message: 'reset public page to workspace information failed',
      errorText:
          l.portalActionFailed,
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
      final draft = answer.draft;
      for (final field in fields ?? publicInheritedFields.toSet()) {
        if (field == publicHostField) {
          _host = draft.hostType ?? _host;
        } else {
          _controllers[field]?.text = draft.text(field) ?? '';
        }
      }
      _following = answer.following;
      _draft = draft;
    });
    if (page != null) ref.invalidate(discoveryListingProvider);
  }

  Future<bool> _confirmResetAll(AppLocalizations l) async {
    final material = MaterialLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l.portalResetAll,
        ),
        content: Text(
          l.portalResetAllBody,
        ),
        actions: [
          TextButton(
            key: const ValueKey('public-page-editor-text-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('public-page-reset-all-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.portalResetAllConfirm),
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

  Widget _textField(String field, String label) => Padding(
                    padding: AppSpacing.smAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          key: ValueKey('public-page-editor-text-field-$field'),
                          controller: _controllers[field]!,
                          enabled: !_busy,
                          maxLength: 4000,
                          maxLines: field == 'description' || field == 'plans'
                              ? 3
                              : 1,
                          onChanged: (_) => _override(field),
                          label: label,
                        ),
                        if (publicInheritedFields.contains(field))
                          _inheritance(field, context.l10n),
                      ],
                    ),
                  );

  Widget _inheritance(String field, AppLocalizations l) => _InheritedStatus(
    key: ValueKey('public-page-inherit-$field'),
    following: _following.contains(field),
    busy: _busy,
    l: l,
    onReset: () => _reset({field}),
  );

  /// #3689 — where the business is on the map, beside the address it uses.
  Widget _placeSection() => ListenableBuilder(
    listenable: Listenable.merge([_controllers['address'], _place]),
    builder: (context, _) => PublicPagePlace(
      key: const ValueKey('public-page-place-section'),
      place: _place.value,
      address: _controllers['address']!.text,
      scope: (_workspace, _account),
      enabled: !_busy,
      onChanged: (p) => _place.value = p,
    ),
  );

  /// Another workspace or account: what was read of the last one goes.
  void _forget(String? workspace, String? account) {
    _account = account;
    _workspace = workspace;
    _loaded = false;
    _failed = false;
    _loading = false;
    _busy = false;
    _place.value = null;
    _offer = null;
    _facetChanges.value = const PublicationDraft();
    _hoursNote.clear();
    for (final c in _controllers.values) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final owner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;
    final account = ref.watch(authStateProvider).value;
    if (workspace?.id != _workspace || account != _account) {
      _forget(workspace?.id, account);
    }
    if (_workspace != null && owner && !_loaded && !_failed && !_loading) {
      _loading = true;
      unawaited(Future.microtask(() => _load(workspace!.id)));
    }
    final labels = {
      'description': l.portalDescription,
      'address': l.portalAddress,
      'email': l.portalEmail,
      'phone': l.portalPhone,
      'website': l.portalWebsite,
      'image_url': l.portalImage,
      'plan_url': l.portalPublicPlan,
      'plans': l.portalPlans,
    };
    return Scaffold(
      appBar: pageBar(context,
        title: l.portalPublication,
      ),
      body: !owner
          ? const SizedBox.shrink()
          : !_loaded
          ? (_failed
                ? Center(
                    child: TextButton(
                      key: const ValueKey('public-page-editor-retry'),
                      onPressed: () => _load(_workspace!),
                      child: Text(l.commonRetry),
                    ),
                  )
                : const LoadingView())
          : FormScroll(
              padding: AppSpacing.mdAll,
              children: [
                SwitchListTile(
                  key: const ValueKey('public-page-editor-portal-published'),
                  value: _published,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _published = v),
                  title: Text(l.portalPublished),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('public-page-host-$_host'),
                  initialValue: _host,
                  items: [
                    for (final type in ['association', 'company', 'person'])
                      DropdownMenuItem(
                        value: type,
                        child: Text(switch (type) {
                          'association' =>
                            l.portalAssociation,
                          'company' => l.portalCompany,
                          _ => l.portalPerson,
                        }),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null || v == _host) return;
                          _override(publicHostField);
                          setState(() => _host = v);
                        },
                ),
                _inheritance(publicHostField, l),
                for (final field in _fields)
                  _textField(field, labels[field]!),
                _placeSection(),
                PublicFacetsEditor(offer: _offer, stored: _draft, draft: _facetChanges,
                  hoursController: _hoursNote, enabled: !_busy,
                  hasPlaces: effectiveFeatures(resolveEnabledFeatures(workspace!.featureFlags))
                      .contains(WorkspaceFeature.placeBooking)),
                PublicOfferPreview(offer: _offer),
                Padding(
                  padding: AppSpacing.smAll,
                  child: OutlinedButton(
                    key: const ValueKey('public-page-reset-all'),
                    onPressed: _busy ? null : () => _reset(null),
                    child: Text(
                      l.portalResetAll,
                    ),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('public-page-editor-portal-save-preview'),
                  onPressed: _busy ? null : _save,
                  child: Text(
                    l.portalSavePreview,
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
  final AppLocalizations l;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final status = following
        ? l.portalFollowsWorkspace
        : l.portalCustomised;
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
            key: const ValueKey('public-page-editor-portal-use-workspace-info'),
            onPressed: busy ? null : onReset,
            child: Text(
              l.portalUseWorkspaceInfo,
            ),
          ),
      ],
    );
  }
}
