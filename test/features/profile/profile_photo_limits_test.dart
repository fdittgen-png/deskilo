// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3710 — a photo over the bucket's limit or of another type is refused
// before the upload.
import 'package:deskilo/features/profile/domain/profile_photo_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a photo within the limit and of an accepted type passes', () {
    checkProfilePhoto(profilePhotoMaxMegabytes * 1024 * 1024, 'image/png');
    checkProfilePhoto(1, 'image/WEBP');
  });

  test('a photo over the limit is refused', () {
    expect(
      () => checkProfilePhoto(
        profilePhotoMaxMegabytes * 1024 * 1024 + 1,
        'image/jpeg',
      ),
      throwsA(isA<ProfilePhotoRefused>()),
    );
  });

  test('a photo of another type is refused', () {
    expect(
      () => checkProfilePhoto(10, 'image/gif'),
      throwsA(isA<ProfilePhotoRefused>()),
    );
  });
}
