// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/directory_providers.dart';
import '../../providers/messenger_providers.dart';
import 'context_thread_screen.dart';
import 'refusal_text.dart';

/// A new group of people (0384): a name, then whoever can be found. Who may
/// be put in a group is each person's own choice — the server refuses anyone
/// who did not make themselves reachable by you.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupState();
}

class _CreateGroupState extends ConsumerState<CreateGroupScreen> {
  final _title = TextEditingController();
  final _search = TextEditingController();
  final _people = <String, String>{};
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? id;
    final ok = await runMessenger(
      context,
      message: 'create group failed',
      errorText: l10n?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () async => id = await ref
          .read(messengerActionsProvider())
          .createGroup(_title.text, _people.keys.toList()),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final created = id;
    if (!ok || created == null) return;
    ref.invalidate(unifiedInboxProvider);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ContextThreadScreen(
          kind: MessageContextKind.accountGroup,
          contextId: created,
          title: _title.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = _query.isEmpty
        ? const AsyncData<List<Map<String, dynamic>>>([])
        : ref.watch(accountContactsProvider(_query));
    final ready = _title.text.trim().isNotEmpty && _people.isNotEmpty && !_busy;
    return Scaffold(
      key: const ValueKey('create-group'),
      appBar: AppBar(title: Text(l10n?.groupNewTitle ?? 'New group')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: AppSpacing.mdAll,
            children: [
              TextField(
                key: const ValueKey('create-group-name'),
                controller: _title,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n?.groupName ?? 'Group name',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n?.groupPeople ?? 'People in the group',
                  style: theme.textTheme.titleSmall),
              if (_people.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    l10n?.groupNeedsPeople ?? 'Add at least one person.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final e in _people.entries)
                      InputChip(
                        key: ValueKey('create-group-chip-${e.key}'),
                        label: Text(e.value),
                        onDeleted: () => setState(() => _people.remove(e.key)),
                      ),
                  ],
                ),
              TextField(
                key: const ValueKey('create-group-search'),
                controller: _search,
                decoration: InputDecoration(
                  labelText: l10n?.groupPickPeople ?? 'Add people',
                  suffixIcon: IconButton(
                    key: const ValueKey('create-group-go'),
                    tooltip: l10n?.portalFindPeople ?? 'Find available people',
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _query = _search.text.trim()),
                  ),
                ),
                onSubmitted: (v) => setState(() => _query = v.trim()),
              ),
              if (results.hasValue)
                for (final p in results.value!)
                  if (!_people.containsKey('${p['id']}'))
                    ListTile(
                      key: ValueKey('create-group-person-${p['id']}'),
                      leading: const Icon(Icons.person_add_alt_outlined),
                      title: Text('${p['name'] ?? ''}'),
                      onTap: () => setState(
                          () => _people['${p['id']}'] = '${p['name'] ?? ''}'),
                    ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const ValueKey('create-group-submit'),
                onPressed: ready ? _create : null,
                child: Text(l10n?.groupCreate ?? 'Create group'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
