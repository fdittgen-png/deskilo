// SPDX-License-Identifier: AGPL-3.0-or-later
import 'personal_info.dart';
import 'profile.dart';

/// #1833 — why a field of another person's profile may be read.
///
/// The server (`member_profiles`, migration 0319) decides which purposes
/// the caller holds for each person and sends one group per purpose. The
/// field matrix is docs/security/IDENTITY_PROJECTIONS.md.
enum ProfilePurpose {
  /// What a space mate sees: name, photo, WhatsApp, status, presence.
  community('community'),

  /// What documents print: the structured identity, the legacy postal
  /// address and the document language. Only for holders of
  /// `viewPersonalData` or `issueInvoices` in that space, and for the
  /// person themselves.
  operational('operational');

  const ProfilePurpose(this.wire);

  /// The group key on the wire, and its entry in `purposes`.
  final String wire;
}

/// The fields each purpose's group may carry, by wire key. A key outside
/// its group is never read, so a field the server put in the wrong place
/// (or a new column nobody classified) does not reach the app.
const Map<ProfilePurpose, List<String>> profilePurposeFields = {
  ProfilePurpose.community: [
    'display_name',
    'avatar_path',
    'whatsapp',
    'status_text',
    'last_seen_at',
  ],
  ProfilePurpose.operational: [
    PersonalInfo.keyCourtesy,
    PersonalInfo.keyFirstName,
    PersonalInfo.keyLastName,
    PersonalInfo.keyCompany,
    PersonalInfo.keyStreet,
    PersonalInfo.keyPostalCode,
    PersonalInfo.keyCity,
    PersonalInfo.keyCountryCode,
    PersonalInfo.keyPhone,
    PersonalInfo.keyEmail,
    PersonalInfo.keyVatId,
    PersonalInfo.keyLegalId,
    'address',
    'preferred_locale',
  ],
};

/// The purposes one projection row was granted: listed in `purposes` AND
/// carried as a group. Either alone grants nothing.
Set<ProfilePurpose> projectionPurposes(Map<String, dynamic> row) {
  final listed = {
    for (final p in (row['purposes'] as List<dynamic>? ?? const <dynamic>[]))
      if (p is String) p,
  };
  return {
    for (final purpose in ProfilePurpose.values)
      if (listed.contains(purpose.wire) && row[purpose.wire] is Map) purpose,
  };
}

/// One `member_profiles` row as a [Profile]. Fields of a purpose the
/// caller does not hold stay at their empty defaults; nothing is read
/// from outside the group its purpose names.
Profile profileFromProjection(Map<String, dynamic> row) {
  final purposes = projectionPurposes(row);
  final flat = <String, dynamic>{'id': row['id']};
  for (final purpose in purposes) {
    final group = (row[purpose.wire] as Map).cast<String, dynamic>();
    for (final key in profilePurposeFields[purpose]!) {
      if (group.containsKey(key)) flat[key] = group[key];
    }
  }
  return Profile.fromDb(flat);
}
