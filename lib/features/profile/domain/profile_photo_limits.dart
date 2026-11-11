// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3710 — what a profile photo may be. The storage bucket `avatars` is the
// authority (supabase/migrations/0716_storage_bucket_limits.sql); these
// constants MIRROR it so the person is told before the upload and in the
// same words when the server refuses. Change both together.

/// The bucket's size limit, in megabytes (mirrors `avatars` in 0716).
const int profilePhotoMaxMegabytes = 5;

/// The bucket's size limit in bytes.
const int _maxBytes = profilePhotoMaxMegabytes * 1024 * 1024;

/// The content types the bucket accepts (mirrors `avatars` in 0716).
const List<String> _contentTypes = [
  'image/jpeg',
  'image/png',
  'image/webp',
];

/// A photo the limits refuse: too big, or not an accepted type. The screen
/// answers with one sentence that names both limits.
class ProfilePhotoRefused implements Exception {
  const ProfilePhotoRefused();

  @override
  String toString() => 'ProfilePhotoRefused';
}

/// Throws [ProfilePhotoRefused] when the size or the type break the limits.
void checkProfilePhoto(int length, String contentType) {
  if (length > _maxBytes ||
      !_contentTypes.contains(contentType.toLowerCase())) {
    throw const ProfilePhotoRefused();
  }
}
