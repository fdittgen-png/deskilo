// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/messenger.dart';
import '../../domain/recipient_search.dart';
import '../../providers/directory_providers.dart';
import '../../providers/messenger_providers.dart';
import '../reachable_directory.dart';
import 'open_inbox_entry.dart';

/// #2472 — the new-discussion search suggests as I type, from the first
/// letter: the people I can write to on every server and my groups,
/// ranked prefix first (first or last name), then names that only contain
/// what I typed, accent- and case-insensitive. Up / Down move, Enter or a
/// tap opens the conversation, Esc closes the list. The suggestions come
/// from the directory already loaded (my_reachable_people answers at most
/// 1000 rows, unpaged), so no keystroke asks a server; Enter with nothing
/// suggested runs the full search ([onSearch]) for people I share no
/// workspace with.
class RecipientTypeahead extends ConsumerStatefulWidget {
  const RecipientTypeahead({
    super.key,
    required this.controller,
    required this.servers,
    required this.onOpen,
    required this.onSearch,
    this.self,
  });

  final TextEditingController controller;

  /// Server origin to its host label; '' is this server.
  final Map<String, String> servers;
  final String? self;
  final void Function(String source, String id, String name) onOpen;
  final ValueChanged<String> onSearch;

  @override
  ConsumerState<RecipientTypeahead> createState() => _TypeaheadState();
}

class _TypeaheadState extends ConsumerState<RecipientTypeahead> {
  final _focus = FocusNode();
  List<Recipient> _all = const [];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<Recipient> _load() {
    final bySource = {
      for (final source in widget.servers.keys)
        source:
            ref.watch(reachablePeopleProvider(source: source)).value ??
            const [],
    };
    final entries = ref.watch(unifiedInboxProvider).value?.entries ?? const [];
    return [
      ...recipientsOf(bySource, hostOf: widget.servers, self: widget.self),
      for (final e in entries)
        if (e.kind == MessageContextKind.accountGroup) Recipient.group(e),
    ];
  }

  void _select(Recipient r) {
    widget.controller.clear();
    final group = r.group;
    if (group != null) {
      unawaited(openInboxEntry(context, ref, group));
    } else {
      widget.onOpen(r.source, r.id, r.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    _all = _load();
    return RawAutocomplete<Recipient>(
      key: const ValueKey('recipient-typeahead'),
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (r) => r.name,
      optionsBuilder: (value) => suggestRecipients(_all, value.text),
      onSelected: _select,
      fieldViewBuilder: (context, controller, focus, onFieldSubmitted) =>
          TextField(
            key: const ValueKey('account-messenger-portal-find-people-2'),
            controller: controller,
            focusNode: focus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l.portalFindPeople,
              hintText: l.portalRecipientHint,
              suffixIcon: IconButton(
                key: const ValueKey('account-messenger-portal-find-people'),
                tooltip: l.portalFindPeople,
                icon: const Icon(Icons.search),
                onPressed: () => widget.onSearch(controller.text.trim()),
              ),
            ),
            onSubmitted: (value) {
              if (suggestRecipients(_all, value).isEmpty) {
                widget.onSearch(value.trim());
              } else {
                onFieldSubmitted();
              }
            },
          ),
      optionsViewBuilder: (context, onSelected, options) => _Suggestions(
        key: const ValueKey('recipient-suggestion-list'),
        options: options.toList(),
        onSelected: onSelected,
      ),
    );
  }
}

/// The list under the field; the highlighted row follows Up / Down.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    super.key,
    required this.options,
    required this.onSelected,
  });
  final List<Recipient> options;
  final AutocompleteOnSelected<Recipient> onSelected;

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        key: const ValueKey('recipient-suggestions'),
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) => Builder(
              builder: (context) {
                if (i == highlighted) _keepVisible(context);
                return _row(context, options[i], i == highlighted);
              },
            ),
          ),
        ),
      ),
    );
  }

  // Up / Down past the visible rows scrolls the highlighted one in.
  void _keepVisible(BuildContext context) =>
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Scrollable.ensureVisible(context, alignment: 0.5);
      });

  Widget _row(BuildContext context, Recipient r, bool selected) {
    final l = context.l10n;
    final detail = r.isGroup
        ? l.portalSuggestionGroup
        : r.workspaces.join(', ');
    return Semantics(
      button: true,
      label: l.portalWriteTo(r.name),
      child: ListTile(
        key: ValueKey('recipient-suggestion-${r.key}'),
        selected: selected,
        leading: RecipientAvatar(name: r.name, group: r.isGroup),
        title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => onSelected(r),
      ),
    );
  }
}
