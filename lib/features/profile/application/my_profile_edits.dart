// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the writes My account makes about the signed-in person, behind
// one command (ADR 0024), so the tiles that moved into Me say what the
// person asked for and resolve no repository themselves.
import 'dart:typed_data';

import '../domain/profile_repository.dart';

class MyProfileEdits {
  const MyProfileEdits(this._profiles);

  final ProfileRepository _profiles;

  /// My profile photo (0038).
  Future<void> setPhoto(Uint8List bytes, {String? contentType}) =>
      _profiles.setAvatar(bytes: bytes, contentType: contentType ?? 'image/jpeg');

  Future<void> removePhoto() => _profiles.clearAvatar();

  /// The invoice block, in one write (#1532).
  Future<void> saveInvoiceIdentity({
    required String address,
    required String countryCode,
    required String vatId,
  }) =>
      _profiles.updateInvoiceIdentity(
        address: address,
        countryCode: countryCode,
        vatId: vatId,
      );
}
