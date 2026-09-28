// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:web/web.dart' as web;

void clearCallbackHistory() {
  final uri = Uri.parse(web.window.location.href);
  final query = Map<String, String>.from(uri.queryParameters);
  for (final key in [
    'code',
    'error',
    'error_code',
    'error_description',
    'deskilo_origin',
    'deskilo_flow',
  ]) {
    query.remove(key);
  }
  web.window.history.replaceState(
    null,
    '',
    uri.replace(queryParameters: query).toString(),
  );
}
