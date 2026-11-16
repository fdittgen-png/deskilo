// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3916 -- the app's address for the functions that link back to the app.
//
// `deskilo-mcp` and `accounting-connect` read the function setting
// `DESKILO_APP_URL` to build a link back to the app. The instance builder sets
// it from the web base the instance's sign-in settings already name, and the
// doctor says when a deployed function that needs it has none or has another
// address. The setting is an address, but it travels the same road as secrets
// (the project's Edge secrets): only its name is ever printed or logged, and
// the doctor reads the digest the API lists, never a value.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'doctor_finding.dart';

/// The name of the function setting that holds the app's address.
const String appUrlSetting = 'DESKILO_APP_URL';

/// The functions whose source reads [appUrlSetting] (pinned to the sources by
/// test/core/instance/app_url_setting_test.dart).
const List<String> appUrlFunctions = ['accounting-connect', 'deskilo-mcp'];

/// The app's address for the functions, from the instance's sign-in settings
/// ([auth], whose `site_url` is the web base): the web base without its
/// trailing slashes, as the functions read it.
String appUrlOf(Map<String, Object?> auth) =>
    '${auth['site_url']}'.replaceAll(RegExp(r'/+$'), '');

/// The digest of [value], lower-case hex: what the API lists of a setting.
String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

/// A digest the Management API lists, or the digest of a raw value if an API
/// version answers the value itself (it is hashed here, never kept).
String _secretDigest(String listed) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(listed) ? listed : sha256Hex(listed);

/// The doctor's finding on the app address of the deployed functions that
/// need it: none when none is deployed or the setting is the instance's own
/// web base ([webBase] with or without its trailing slash), a warning when it
/// is not set, an alarm when it is another address. Only the digest of the
/// listed value is compared, so another origin and another path read alike.
/// A finding names the functions, never a value.
List<DoctorFinding> checkAppUrl({
  required List<String> deployed,
  required Map<String, String> digests,
  required String webBase,
}) {
  final needing = [
    for (final slug in appUrlFunctions)
      if (deployed.contains(slug)) slug,
  ];
  if (needing.isEmpty) return const [];
  final facts = [needing.join(', ')];
  final listed = digests[appUrlSetting];
  if (listed == null || listed.isEmpty) {
    return [
      DoctorFinding.typed(
        DoctorLevel.warn,
        DoctorWords.appUrlMissing,
        facts: facts,
      ),
    ];
  }
  final base = webBase.replaceAll(RegExp(r'/+$'), '');
  final own = {sha256Hex(base), sha256Hex('$base/')};
  if (own.contains(_secretDigest(listed))) return const [];
  return [
    DoctorFinding.typed(
      DoctorLevel.alarm,
      DoctorWords.appUrlForeign,
      facts: facts,
    ),
  ];
}
