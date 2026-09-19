// SPDX-License-Identifier: 0BSD
//
// #1528 — defining a role a workspace invents for itself.
//
// The permissions are CHOSEN from the catalogue, never typed: 0247
// validates every one against `role_permission_catalog()`, and a list of
// switches is the only shape where an owner cannot ask for something the
// product does not have.
//
// The key is written once and never again, like a question's (#1288):
// the people holding the role point at it, so a renamed key is a role
// nobody holds.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_role.dart';
import '../screens/roles_screen_labels.dart';

/// Edits [initial], or defines a new role when it is null.
class RoleEditorSheet extends StatefulWidget {
  const RoleEditorSheet({
    super.key,
    this.initial,
    required this.workspaceLocale,
    required this.onSave,
    this.saving = false,
  });

  final WorkspaceRole? initial;

  /// The language the workspace reads; 0247 insists on a name in it.
  final String workspaceLocale;
  final Future<void> Function(WorkspaceRole role) onSave;
  final bool saving;

  static const Key saveKey = Key('role-editor-save');
  static const Key keyFieldKey = Key('role-editor-key');

  static Key nameKeyFor(String locale) => ValueKey('role-editor-name-$locale');
  static Key permissionKeyFor(WorkspacePermission p) =>
      ValueKey('role-editor-permission-${p.wireName}');

  @override
  State<RoleEditorSheet> createState() => _RoleEditorSheetState();
}

class _RoleEditorSheetState extends State<RoleEditorSheet> {
  static const _locales = ['en', 'fr', 'de', 'es', 'it'];

  late final TextEditingController _key;
  late final Map<String, TextEditingController> _names;
  late Set<WorkspacePermission> _permissions;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.initial?.key ?? '');
    _names = {
      for (final locale in _locales)
        locale: TextEditingController(text: widget.initial?.names[locale] ?? ''),
    };
    _permissions = {...?widget.initial?.permissions};
    _active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    _key.dispose();
    for (final c in _names.values) {
      c.dispose();
    }
    super.dispose();
  }

  WorkspaceRole get _draft => WorkspaceRole(
        id: widget.initial?.id ?? '',
        key: _key.text.trim(),
        names: {
          for (final entry in _names.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        },
        permissions: _permissions,
        sortOrder: widget.initial?.sortOrder ?? 0,
        active: _active,
      );

  bool get _canSave =>
      !widget.saving &&
      roleProblem(_draft, widget.workspaceLocale) == null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.initial == null)
                TextField(
                  key: RoleEditorSheet.keyFieldKey,
                  controller: _key,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n?.roleEditorKey ?? 'Key',
                    helperText: l10n?.roleEditorKeyHelp ??
                        'Lower-case letters, digits and underscores. It '
                            'never changes: the people who hold the role '
                            'point at it.',
                    helperMaxLines: 3,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: AppSpacing.md),
              for (final locale in _locales)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(
                    key: RoleEditorSheet.nameKeyFor(locale),
                    controller: _names[locale],
                    decoration: InputDecoration(
                      labelText:
                          l10n?.roleEditorNameFor(locale) ?? 'Name ($locale)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.roleEditorActive ?? 'In use'),
                value: _active,
                onChanged:
                    widget.saving ? null : (on) => setState(() => _active = on),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n?.roleEditorPermissions ?? 'What it adds',
                style: theme.textTheme.labelLarge,
              ),
              // Chosen, never typed: 0247 validates every one against the
              // catalogue, and a list of switches cannot ask for a
              // permission the product does not have.
              for (final permission in WorkspacePermission.values)
                SwitchListTile(
                  key: RoleEditorSheet.permissionKeyFor(permission),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(permissionLabel(l10n, permission)),
                  value: _permissions.contains(permission),
                  onChanged: widget.saving
                      ? null
                      : (on) => setState(() {
                            if (on) {
                              _permissions.add(permission);
                            } else {
                              _permissions.remove(permission);
                            }
                          }),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: RoleEditorSheet.saveKey,
                onPressed: _canSave ? () => widget.onSave(_draft) : null,
                child: Text(l10n?.roleEditorSave ?? 'Save the role'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
