// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A state of a page kept in its address (#3625: a record's address is
// `/<list>/<id>`; a state of a page goes in a query): read from the address,
// and written to it without a new history entry. Outside the app's router (a
// widget test pumping the page alone) there is no address: the page keeps
// the state itself.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The value of [key] in the page's address, or null.
String? addressQuery(BuildContext context, String key) {
  if (GoRouter.maybeOf(context) == null) return null;
  return GoRouterState.of(context).uri.queryParameters[key];
}

/// Writes [values] into the page's address without a new history entry; a
/// null value removes its key. False when the page is not under the app's
/// router.
bool setAddressQuery(BuildContext context, Map<String, String?> values) {
  if (GoRouter.maybeOf(context) == null) return false;
  final uri = GoRouterState.of(context).uri;
  final query = {...uri.queryParameters};
  for (final MapEntry(:key, :value) in values.entries) {
    if (value == null) {
      query.remove(key);
    } else {
      query[key] = value;
    }
  }
  if (_same(query, uri.queryParameters)) return true;
  context.replace(
    uri.replace(queryParameters: query.isEmpty ? null : query).toString(),
  );
  return true;
}

bool _same(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
