// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 — who a new discussion can go to, and what typing a few letters
// suggests. Pure: the server already decided who is reachable (0547) and
// which groups I am in (my_inbox); this only merges, folds and ranks what
// was loaded, so a keystroke never asks a server anything.
import 'messenger.dart';
import 'public_workspace.dart';

/// One person or group a discussion can be started with.
class Recipient {
  const Recipient.person({
    required this.source,
    required this.id,
    required this.name,
    required this.workspaces,
  }) : group = null;

  Recipient.group(InboxEntry this.group)
    : source = group.source,
      id = group.contextId,
      name = group.title,
      workspaces = const [];

  /// The server's origin; '' is this server.
  final String source;
  final String id, name;

  /// The shared workspaces a person belongs to, as shown under the name.
  final List<String> workspaces;

  /// The group's inbox entry; null for a person.
  final InboxEntry? group;

  bool get isGroup => group != null;
  String get key => '${isGroup ? 'g' : 'p'}:$source:$id';
}

const _folds = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// [text] lower-cased with its Latin accents removed, so "Élodie" and
/// "elodie" match.
String _fold(String text) {
  final out = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    out.write(_folds[char] ?? char);
  }
  return out.toString();
}

/// Everyone I can write to, once per person per server, with every
/// workspace I share with them; [hostOf] names a server that is not this
/// one. My own account ([self], on this server) is never a recipient.
List<Recipient> recipientsOf(
  Map<String, List<ReachablePerson>> bySource, {
  required Map<String, String> hostOf,
  String? self,
}) {
  final names = <String, String>{};
  final spaces = <String, List<String>>{};
  for (final entry in bySource.entries) {
    final host = hostOf[entry.key] ?? '';
    final mine = entry.key.isEmpty ? self : null;
    for (final p in entry.value.where((p) => p.id != mine)) {
      final key = '${entry.key}\n${p.id}';
      names[key] = p.name;
      final list = spaces.putIfAbsent(key, () => []);
      final label = _spaceLabel(p.workspaceName, host);
      if (!list.contains(label)) list.add(label);
    }
  }
  return [
    for (final key in names.keys)
      Recipient.person(
        source: key.split('\n').first,
        id: key.split('\n').last,
        name: names[key]!,
        workspaces: spaces[key]!,
      ),
  ];
}

String _spaceLabel(String workspace, String host) =>
    host.isEmpty ? workspace : '$workspace · $host';

/// How well [name] answers [query] (both folded): 0 the name starts with
/// it, 1 a later word (a last name) does, 2 it appears inside; null no
/// match.
int? _matchRank(String name, String query) {
  if (query.isEmpty) return null;
  if (name.startsWith(query)) return 0;
  final words = name.split(RegExp(r'[\s\-_.]+'));
  if (words.skip(1).any((w) => w.startsWith(query))) return 1;
  return name.contains(query) ? 2 : null;
}

/// What [query] suggests among [all]: prefix matches on the whole name or
/// any of its words (first, last), then names that only contain it,
/// accent- and case-insensitive; alphabetical within a rank, at most
/// [limit].
List<Recipient> suggestRecipients(
  Iterable<Recipient> all,
  String query, {
  int limit = 8,
}) {
  final folded = _fold(query.trim());
  final ranked = <(int, String, Recipient)>[];
  for (final r in all) {
    final name = _fold(r.name);
    final rank = _matchRank(name, folded);
    if (rank != null) ranked.add((rank, name, r));
  }
  ranked.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final r in ranked.take(limit)) r.$3];
}

/// Up to two initials of [name], for the avatar of a row without a photo.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = [for (final w in words.take(2)) w[0].toUpperCase()];
  return letters.isEmpty ? '?' : letters.join();
}
