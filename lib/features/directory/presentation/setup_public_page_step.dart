// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "public page": whether the space is published, and the
// words people outside read first (description, e-mail, phone, website),
// prefilled from the stored page and saved through the editor's own write
// ([PublicationActions.savePage]). Every other field of the page is sent
// back as it was read, and a field that follows the workspace information
// keeps following it unless the owner changed it here. The address, the
// image and the plans stay in the page editor, one tap away. The preview
// is the space as the directory lists it, then what its page says, drawn
// from the fields as the owner types. What the owner typed and has not
// saved is kept as the step's draft on the server (#2869), through the
// frame the guide hands in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/async_read_body.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/ui/setup_draft_form.dart';
import '../../../core/ui/setup_step_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/dictionary_labels.dart';
import '../domain/public_workspace.dart';
import '../domain/publication_draft.dart';
import '../providers/directory_providers.dart';
import '../providers/discovery_listing_providers.dart';

/// The fields this step edits, in the order the page shows them.
const _edited = ['description', 'email', 'phone', 'website'];

class SetupPublicPageStep extends ConsumerStatefulWidget {
  const SetupPublicPageStep({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
    required this.draft,
  });

  final String workspaceId;

  /// Shown until the stored page names the space itself.
  final String workspaceName;

  /// Keeps what the owner typed and has not saved as the step's draft.
  final SetupDraftFrameBuilder draft;

  @override
  ConsumerState<SetupPublicPageStep> createState() =>
      _SetupPublicPageStepState();
}

class _SetupPublicPageStepState extends ConsumerState<SetupPublicPageStep> {
  late Future<OwnPublicPage> _read = _readPage();

  Future<OwnPublicPage> _readPage() =>
      ref.read(publicationActionsProvider).ownPage(widget.workspaceId);
  final _controllers = {
    for (final field in _edited) field: TextEditingController(),
  };
  final _published = ValueNotifier<bool>(false);
  final _busy = ValueNotifier<bool>(false);

  /// The page as last read or saved, the name it stores, and the
  /// inherited fields that still follow the workspace information.
  PublicationDraft? _stored;
  String? _name;
  Set<String> _following = const {};

  /// Whether the page was published when last read or saved.
  var _storedPublished = false;

  late final _kept = SetupDraftForm(
    edits: Listenable.merge([_published, ..._controllers.values]),
    answers: () => {
      'published': _published.value,
      for (final field in _edited) field: _controllers[field]!.text,
    },
    fill: (answers) {
      _published.value = switch (answers?['published']) {
        final bool published => published,
        _ => _storedPublished,
      };
      for (final field in _edited) {
        _controllers[field]!.text = switch (answers?[field]) {
          final String typed => typed,
          _ => _stored?.text(field) ?? '',
        };
      }
    },
  );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _published.dispose();
    _busy.dispose();
    super.dispose();
  }

  void _prefill(OwnPublicPage page) {
    if (_stored != null) return;
    _stored = page.draft;
    _name = page.name;
    _following = page.following;
    _published.value = _storedPublished = page.published;
    for (final field in _edited) {
      _controllers[field]!.text = page.draft.text(field) ?? '';
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final stored = _stored ?? const PublicationDraft();
    final changed = {
      for (final field in _edited)
        if (_controllers[field]!.text.trim() != (stored.text(field) ?? '')) field,
    };
    final document = stored.diff(stored.copyWith(texts: _typed()));
    final following = _following.difference(changed);
    _busy.value = true;
    PublicWorkspace? saved;
    final ok = await runGuarded(
      context,
      domain: 'directory',
      message: 'setup public page save failed',
      errorText: l10n.portalActionFailed,
      action: () async => saved = await ref
          .read(publicationActionsProvider)
          .savePage(
            widget.workspaceId,
            document,
            following: following,
            published: _published.value,
          ),
    );
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    final answer = saved;
    if (answer != null) {
      _stored = PublicationDraft.fromDocument(answer.document);
      _name = storedPageName(answer);
    }
    _following = following;
    _storedPublished = _published.value;
    ref.invalidate(discoveryListingProvider);
    AppSnack.success(context, l10n.billingSaved);
    await _kept.applied();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OwnPublicPage>(
    future: _read,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: AppSpacing.lgAll,
          child: ReadFailureBanner(
            key: const ValueKey('setup-public-page-failed'),
            error: snapshot.error!,
            onRetry: () => setState(() => _read = _readPage()),
          ),
        );
      }
      final page = snapshot.data;
      if (page == null) return const LoadingView();
      _prefill(page);
      return SetupStepLayout(
        form: widget.draft(form: _kept, child: _form(context)),
        preview: ListenableBuilder(
          listenable: Listenable.merge([_published, ..._controllers.values]),
          builder: (context, _) => _Preview(
            name: _name ?? widget.workspaceName,
            draft: (_stored ?? const PublicationDraft()).copyWith(
              texts: _typed(),
            ),
            published: _published.value,
          ),
        ),
      );
    },
  );

  /// What the owner typed in the fields of this step.
  Map<String, String> _typed() => {
    for (final field in _edited) field: _controllers[field]!.text.trim(),
  };

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      'description': l10n.portalDescription,
      'email': l10n.portalEmail,
      'phone': l10n.portalPhone,
      'website': l10n.portalWebsite,
    };
    return ValueListenableBuilder<bool>(
      valueListenable: _busy,
      builder: (context, busy, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.setupStepHint('public_page')),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<bool>(
            valueListenable: _published,
            builder: (context, published, _) => SwitchListTile(
              key: const ValueKey('setup-public-page-published'),
              contentPadding: EdgeInsets.zero,
              value: published,
              onChanged: busy ? null : (v) => _published.value = v,
              title: Text(l10n.portalPublished),
            ),
          ),
          for (final field in _edited)
            AppTextField(
              key: ValueKey('setup-public-page-$field'),
              controller: _controllers[field]!,
              label: labels[field]!,
              enabled: !busy,
              maxLength: 4000,
              maxLines: field == 'description' ? 3 : 1,
              keyboardType: switch (field) {
                'email' => TextInputType.emailAddress,
                'phone' => TextInputType.phone,
                'website' => TextInputType.url,
                _ => null,
              },
              autofillHints: switch (field) {
                'email' => const [AutofillHints.email],
                'phone' => const [AutofillHints.telephoneNumber],
                'website' => const [AutofillHints.url],
                _ => null,
              },
            ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                key: const ValueKey('setup-public-page-save'),
                onPressed: busy ? null : _save,
                child: Text(l10n.commonSave),
              ),
              TextButton(
                key: const ValueKey('setup-public-page-open'),
                onPressed: () => context.push(Routes.settingsPublicPage),
                child: Text(l10n.setupPublicPageMore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The space as the directory lists it (its name over its address), then
/// the words its public page carries.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.draft,
    required this.published,
  });

  final String name;
  final PublicationDraft draft;
  final bool published;

  String _text(String field) => draft.text(field) ?? '';

  static String _host(AppLocalizations l10n, String type) => switch (type) {
    'association' => l10n.portalAssociation,
    'company' => l10n.portalCompany,
    _ => l10n.portalPerson,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('setup-public-page-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!published) ...[
          InlineBanner(
            key: const ValueKey('setup-public-page-unpublished'),
            icon: Icons.visibility_off_outlined,
            severity: InlineBannerSeverity.info,
            text: l10n.setupPublicPageNotPublished,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Card(
          child: ListTile(title: Text(name), subtitle: Text(_text('address'))),
        ),
        Padding(
          padding: AppSpacing.smAll,
          child: Text(_host(l10n, draft.hostType ?? '')),
        ),
        for (final field in _edited)
          if (_text(field).isNotEmpty)
            Padding(
              key: ValueKey('setup-public-page-preview-$field'),
              padding: AppSpacing.smAll,
              child: Text(_text(field)),
            ),
      ],
    );
  }
}
