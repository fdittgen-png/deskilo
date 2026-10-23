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
// from the fields as the owner types.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/ui/setup_step_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_providers.dart';

/// The fields this step edits, in the order the page shows them.
const _edited = ['description', 'email', 'phone', 'website'];

class SetupPublicPageStep extends ConsumerStatefulWidget {
  const SetupPublicPageStep({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
  });

  final String workspaceId;

  /// Shown until the stored page names the space itself.
  final String workspaceName;

  @override
  ConsumerState<SetupPublicPageStep> createState() =>
      _SetupPublicPageStepState();
}

class _SetupPublicPageStepState extends ConsumerState<SetupPublicPageStep> {
  late final Future<Map<String, Object?>> _read = ref
      .read(publicationActionsProvider)
      .ownPage(widget.workspaceId);
  final _controllers = {
    for (final field in _edited) field: TextEditingController(),
  };
  final _published = ValueNotifier<bool>(false);
  final _busy = ValueNotifier<bool>(false);

  /// The document as last read or saved, and the inherited fields that
  /// still follow the workspace information.
  Map<String, Object?>? _document;
  Set<String> _following = const {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _published.dispose();
    _busy.dispose();
    super.dispose();
  }

  void _prefill(Map<String, Object?> page) {
    if (_document != null) return;
    final doc = Map<String, Object?>.from(page['document'] as Map);
    _document = doc;
    _following = publicFollowing(page);
    _published.value = page['published'] == true;
    for (final field in _edited) {
      _controllers[field]!.text = doc[field] as String? ?? '';
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final stored = _document ?? const <String, Object?>{};
    final changed = {
      for (final field in _edited)
        if (_controllers[field]!.text.trim() != (stored[field] ?? '')) field,
    };
    // The whole page, as the page editor sends it: what this step does not
    // edit goes back as it was read.
    final document = <String, String>{
      'host_type': stored['host_type'] as String? ?? 'association',
      for (final field in publicPageFields)
        field: _edited.contains(field)
            ? _controllers[field]!.text
            : stored[field] as String? ?? '',
    };
    final following = _following.difference(changed);
    _busy.value = true;
    Map<String, Object?>? saved;
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
    _document = saved ?? _document;
    _following = following;
    ref.invalidate(publicDirectoryProvider);
    AppSnack.success(context, l10n.billingSaved);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
    future: _read,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-public-page-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        );
      }
      final page = snapshot.data;
      if (page == null) return const LoadingView();
      _prefill(page);
      return SetupStepLayout(
        form: _form(context),
        preview: ListenableBuilder(
          listenable: Listenable.merge([_published, ..._controllers.values]),
          builder: (context, _) => _Preview(
            name: _document?['name'] as String? ?? widget.workspaceName,
            document: {
              ...?_document,
              for (final field in _edited)
                field: _controllers[field]!.text.trim(),
            },
            published: _published.value,
          ),
        ),
      );
    },
  );

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
                onPressed: () => context.push('/settings/public-page'),
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
    required this.document,
    required this.published,
  });

  final String name;
  final Map<String, Object?> document;
  final bool published;

  String _text(String field) =>
      document[field] is String ? document[field] as String : '';

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
          child: Text(_host(l10n, _text('host_type'))),
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
