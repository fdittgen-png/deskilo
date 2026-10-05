// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/member.dart';
import '../domain/workspace_permission.dart';

// #1154 — these two ladders were copied into four screens; a status
// renamed in one of them stopped matching the others. One home.

/// Owner / Admin / Member, from the flags on the membership.
String memberRoleLabel(AppLocalizations? l10n, Member member) => member.isOwner
    ? (l10n?.memberRoleOwner ?? 'Owner')
    : member.isAdmin
        ? (l10n?.memberRoleAdmin ?? 'Administrator')
        : (l10n?.memberRoleMember ?? 'Member');

/// The mandatory base role a person holds — exactly one of these four
/// (the permission matrix's rows). [adminName] is what the workspace calls
/// its Administrator.
String baseRoleLabel(AppLocalizations? l10n, PermissionRole role,
        [String? adminName]) =>
    switch (role) {
      PermissionRole.owner => l10n?.memberRoleOwner ?? 'Owner',
      PermissionRole.coOwner => l10n?.memberCoOwnerChip ?? 'Co-owner',
      PermissionRole.admin =>
        adminName ?? l10n?.memberRoleAdmin ?? 'Administrator',
      PermissionRole.member => l10n?.baseRoleUser ?? 'User',
    };

/// Active / Paused / Pending / Exited.
String memberStatusLabel(AppLocalizations? l10n, MemberStatus status) =>
    switch (status) {
      MemberStatus.active => l10n?.memberStatusActive ?? 'Active',
      MemberStatus.paused => l10n?.memberStatusPaused ?? 'Paused',
      MemberStatus.pending => l10n?.memberStatusPending ?? 'Pending',
      MemberStatus.exited => l10n?.memberStatusExited ?? 'Exited',
    };
