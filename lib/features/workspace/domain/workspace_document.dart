// SPDX-License-Identifier: 0BSD

/// One entry of the workspace document library (#500, 0099): a LINK to
/// a document living in whatever system the workspace already uses.
/// The provider only decides the icon and the wording — authentication
/// is the linked system's own business, in the browser.
class WorkspaceDocument {
  const WorkspaceDocument({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.category = 'other',
    this.provider = 'link',
    required this.url,
    this.minRole = 'member',
  });

  final String id;
  final String workspaceId;
  final String title;

  /// 'statutes' | 'guides' | 'finance' | 'minutes' | 'other'.
  final String category;

  /// 'gdrive' | 'onedrive' | 'sharepoint' | 'dropbox' | 'nextcloud' |
  /// 'link'.
  final String provider;

  final String url;

  /// Who sees it: 'member' (everyone) | 'admin' | 'owner'. The server
  /// enforces this in RLS; the client mirrors it for honest UI.
  final String minRole;

  static const List<String> categories = [
    'statutes',
    'guides',
    'finance',
    'minutes',
    'other',
  ];

  static const List<String> providers = [
    'gdrive',
    'onedrive',
    'sharepoint',
    'dropbox',
    'nextcloud',
    'link',
  ];

  static const List<String> roles = ['member', 'admin', 'owner'];

  factory WorkspaceDocument.fromRow(Map<String, dynamic> row) =>
      WorkspaceDocument(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        title: row['title'] as String,
        category: row['category'] as String? ?? 'other',
        provider: row['provider'] as String? ?? 'link',
        url: row['url'] as String,
        minRole: row['min_role'] as String? ?? 'member',
      );
}
