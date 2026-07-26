// SPDX-License-Identifier: 0BSD

/// Lower-case ASCII slug for user-derived export file names (security
/// audit): a workspace or member NAME is free text server-side, so
/// interpolating it raw into a path lets `/` or `..` escape the export
/// directory on the platforms that write via `File(dir/name)`. Every
/// export site slugs through here.
String safeFileSlug(String name) {
  final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'export' : trimmed;
}
