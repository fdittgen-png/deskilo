// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — Settings › Organisation: the organisation this business is a house
// of, its houses with their country and currency and the reader's own role
// in each, and the owners' commands — rename it, add one of their
// businesses, take a house out. A business in no organisation may become
// the head of one. Who owns a house is read inside that house; the server
// decides every command and says why when it does not.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/country_names.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/organisation.dart';
import '../../domain/workspace.dart';
import '../../providers/organisation_providers.dart';
import '../../providers/workspace_providers.dart';

String _roleText(AppLocalizations l10n, HouseRole role) => switch (role) {
  HouseRole.owner => l10n.organisationRoleOwner,
  HouseRole.coOwner => l10n.organisationRoleCoOwner,
  HouseRole.admin => l10n.organisationRoleAdmin,
  HouseRole.member => l10n.organisationRoleMember,
};

String _refusalText(AppLocalizations l10n, OrganisationRefusal r) =>
    switch (r) {
      OrganisationRefusal.notOwner => l10n.organisationRefusedNotOwner,
      OrganisationRefusal.noName => l10n.organisationRefusedNoName,
      OrganisationRefusal.alreadyInOne => l10n.organisationRefusedAlreadyInOne,
      OrganisationRefusal.inNone => l10n.organisationRefusedInNone,
      OrganisationRefusal.headLeavesLast =>
        l10n.organisationRefusedHeadLeavesLast,
      OrganisationRefusal.other => l10n.organisationRefusedOther,
    };

/// The organisation of [workspace], as a sheet over Settings.
class OrganisationSheet extends ConsumerWidget {
  const OrganisationSheet({super.key, required this.workspace});

  final Workspace workspace;

  /// Opens the sheet of [workspace]'s organisation.
  static Future<void> open(BuildContext context, Workspace workspace) =>
      showAppSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => OrganisationSheet(workspace: workspace),
      );

  Future<String?> _askName(BuildContext context, String title, String now) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, initial: now),
      );

  Future<void> _done(
    BuildContext context,
    Future<OrganisationRefusal?> command,
  ) async {
    final refused = await command;
    if (refused != null && context.mounted) {
      AppSnack.error(context, _refusalText(context.l10n, refused));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(organisationCommandsProvider);
    final organisations = ref.watch(myOrganisationsProvider).value ?? const [];
    final spaces = ref.watch(myWorkspacesProvider).value ?? const [];
    final organisation = organisations
        .where((o) => o.houseOf(workspace.id) != null)
        .firstOrNull;
    final title = Row(
      children: [
        Expanded(
          child: Text(
            organisation?.name ?? l10n.organisationTitle,
            key: const ValueKey('organisation-name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (organisation != null)
          IconButton(
            key: const ValueKey('organisation-rename'),
            tooltip: l10n.organisationRename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _askName(
                context,
                l10n.organisationRename,
                organisation.name,
              );
              if (name == null || !context.mounted) return;
              await _done(context, commands.rename(organisation.id, name));
            },
          ),
        HelpDot(l10n.organisationTitle, anchor: HelpAnchor.organisation),
      ],
    );
    return SafeArea(
      child: ListView(
        key: const ValueKey('organisation-sheet'),
        shrinkWrap: true,
        padding: AppSpacing.lgAll,
        children: [
          title,
          const FormGap(),
          if (organisation == null) ...[
            Text(l10n.organisationNone),
            const FormGap(),
            FilledButton(
              key: const ValueKey('organisation-create'),
              onPressed: () async {
                final name = await _askName(
                  context,
                  l10n.organisationCreate,
                  workspace.name,
                );
                if (name == null || !context.mounted) return;
                await _done(context, commands.create(workspace.id, name));
              },
              child: Text(l10n.organisationCreate),
            ),
          ] else ...[
            for (final house in organisation.byCountry)
              ListTile(
                key: ValueKey('organisation-house-${house.workspaceId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  house.workspaceId == organisation.headWorkspaceId
                      ? '${house.name} · ${l10n.organisationHead}'
                      : house.name,
                ),
                subtitle: Text(
                  [
                    if (house.countryCode.isNotEmpty)
                      localizedCountryName(l10n, house.countryCode),
                    if (house.currencyCode.isNotEmpty) house.currencyCode,
                    l10n.organisationYourRole(_roleText(l10n, house.role)),
                  ].join(' · '),
                ),
                trailing: IconButton(
                  key: ValueKey('organisation-remove-${house.workspaceId}'),
                  tooltip: l10n.organisationRemove,
                  icon: const Icon(Icons.logout),
                  onPressed: () =>
                      _done(context, commands.remove(house.workspaceId)),
                ),
              ),
            const FormGap(),
            OutlinedButton.icon(
              key: const ValueKey('organisation-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.organisationAdd),
              onPressed: () =>
                  _add(context, ref, spaces, organisations, organisation),
            ),
          ],
        ],
      ),
    );
  }

  /// Offers the person's businesses in no organisation (one side of a
  /// pair: the server moves its twin with it).
  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<Workspace> spaces,
    List<Organisation> organisations,
    Organisation organisation,
  ) async {
    final l10n = context.l10n;
    final candidates = [
      for (final s in spaces)
        if (!organisations.any((o) => o.houseOf(s.id) != null) &&
            !(s.isDevelopment && s.pairId.isNotEmpty))
          s,
    ];
    if (candidates.isEmpty) {
      AppSnack.info(context, l10n.organisationAddNone);
      return;
    }
    final picked = await showAppSheet<Workspace>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in candidates)
              ListTile(
                key: ValueKey('organisation-candidate-${s.id}'),
                title: Text(s.name),
                subtitle: Text(
                  '${localizedCountryName(l10n, s.countryCode)} · '
                  '${s.currencyCode}',
                ),
                onTap: () => Navigator.of(sheet).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _done(
      context,
      ref.read(organisationCommandsProvider).add(organisation.id, picked.id),
    );
  }
}

/// Asks for the organisation's name.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: AppTextField(
        key: const ValueKey('organisation-name-field'),
        controller: _name,
        label: l10n.organisationName,
        maxLength: 200,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('organisation-name-save'),
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
