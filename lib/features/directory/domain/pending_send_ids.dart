// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3745 -- the request id of a send whose outcome is not known yet. The app
// keeps one per conversation draft until the server answers: a send repeated
// after a lost answer carries the same id, and the server writes it once. A
// changed text is another request. Nothing here deduplicates by text or by a
// time window: only the server's answer settles a request.
import '../../../core/ids/request_id.dart';

class PendingSendIds {
  PendingSendIds([String Function()? newId]) : _newId = newId ?? newRequestId;

  final String Function() _newId;
  final _pending = <String, ({String body, String id})>{};

  /// The id of sending [body] from the draft [key]: the waiting one when the
  /// text is the same, else a new one that replaces it.
  String idFor(String key, String body) {
    final waiting = _pending[key];
    if (waiting != null && waiting.body == body) return waiting.id;
    final id = _newId();
    _pending[key] = (body: body, id: id);
    return id;
  }

  /// The server answered the send from [key]: its id is done.
  void settled(String key) => _pending.remove(key);
}
