// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the person was in Me when they entered a space.
//
// Entering a space replaces the personal shell with the space's, so the
// branch navigators of Me, and every scroll offset in them, are gone when
// the person comes back. What survives is this: the personal location the
// space was entered from, spent on the next arrival at Me's bare address,
// and one page-storage bucket per destination, which each branch page reads
// its scroll offsets from when it is built again.
//
// Both belong to one personal account. Another account signing in, or
// nobody, drops them before anything is read, so no account is ever
// returned to the previous one's place.
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'personal_return_providers.g.dart';

/// The personal place kept across a stay in a space, for one account.
class PersonalReturn {
  String? _account;
  String? _pending;
  final Map<String, PageStorageBucket> _buckets = {};

  /// Holds what is kept for [account] only; anything kept for another is
  /// dropped first.
  void _own(String? account) {
    if (account == _account) return;
    _account = account;
    _pending = null;
    _buckets.clear();
  }

  /// [account] leaves Me from [location] for a space: a personal location
  /// other than Me's bare home is where the next return lands.
  void leave(String? account, Uri location) {
    _own(account);
    final personal = location.path == '/me' || location.path.startsWith('/me/');
    final home = location.path == '/me' && location.query.isEmpty;
    _pending = account != null && personal && !home ? '$location' : null;
  }

  /// Where [account]'s return to Me's bare home lands, or null for home.
  String? resumeFor(String? account) =>
      account != null && account == _account ? _pending : null;

  /// Me is shown again: the next bare home is home.
  void arrived() => _pending = null;

  /// The page storage of the destination [branch] for [account].
  PageStorageBucket bucketFor(String? account, String branch) {
    _own(account);
    return _buckets.putIfAbsent(branch, _KeyedBucket.new);
  }
}

/// A bucket that also tells apart state written under plain [ValueKey]s:
/// the branch pages key their lists with ValueKeys, not PageStorageKeys,
/// and two scrollables under the same keys of different widget types never
/// share an entry.
class _KeyedBucket extends PageStorageBucket {
  static Object? _identify(BuildContext context) {
    final keys = <Key>[];
    bool add(BuildContext at) {
      if (at.widget.key case final ValueKey<Object?> key) keys.add(key);
      return at.widget is! PageStorage;
    }

    if (add(context)) context.visitAncestorElements(add);
    if (keys.isEmpty) return null;
    return _Entry(context.widget.runtimeType, keys);
  }

  @override
  void writeState(BuildContext context, Object? data, {Object? identifier}) =>
      super.writeState(
        context,
        data,
        identifier: identifier ?? _identify(context),
      );

  @override
  Object? readState(BuildContext context, {Object? identifier}) =>
      super.readState(context, identifier: identifier ?? _identify(context));
}

@immutable
class _Entry {
  const _Entry(this.type, this.keys);

  final Type type;
  final List<Key> keys;

  @override
  bool operator ==(Object other) =>
      other is _Entry && other.type == type && listEquals(other.keys, keys);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(keys));
}

@Riverpod(keepAlive: true)
PersonalReturn personalReturn(Ref ref) => PersonalReturn();
