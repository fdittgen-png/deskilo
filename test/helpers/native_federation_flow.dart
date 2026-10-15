// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in native_federation_flow_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'dart:convert';

Map<String, Object?> user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-09-28T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};

Map<String, Object?> session(String id) {
  final jwt = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': id,
        'iss': 'https://target.example/auth/v1',
        'exp':
            4102444800 /* fixed year 2100: the SDK checks real token expiry */,
      }),
    ),
  );
  return {
    'access_token': 'e30.$jwt.signature',
    'refresh_token': 'target-refresh-$id',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': user(id),
  };
}
