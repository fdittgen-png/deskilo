// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/member.dart';

// #1154 — these two ladders were copied into four screens; a status
// renamed in one of them stopped matching the others. One home.

/// Owner / Admin / Member, from the flags on the membership.
String memberRoleLabel(AppLocalizations? l10n, Member member) => member.isOwner
    ? (l10n?.memberRoleOwner ?? 'Owner')
    : member.isAdmin
        ? (l10n?.memberRoleAdmin ?? 'Admin')
        : (l10n?.memberRoleMember ?? 'Member');

/// Active / Paused / Pending / Exited.
String memberStatusLabel(AppLocalizations? l10n, MemberStatus status) =>
    switch (status) {
      MemberStatus.active => l10n?.memberStatusActive ?? 'Active',
      MemberStatus.paused => l10n?.memberStatusPaused ?? 'Paused',
      MemberStatus.pending => l10n?.memberStatusPending ?? 'Pending',
      MemberStatus.exited => l10n?.memberStatusExited ?? 'Exited',
    };
