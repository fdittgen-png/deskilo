// SPDX-License-Identifier: AGPL-3.0-or-later

/// The route of Me › Finances, optionally narrowed to one workspace — what a
/// workspace's own screens link to for "my documents from this space".
String myFinancesRoute({String? workspaceId}) =>
    workspaceId == null || workspaceId.isEmpty
        ? '/account-activity'
        : '/account-activity?workspace=${Uri.encodeQueryComponent(workspaceId)}';
