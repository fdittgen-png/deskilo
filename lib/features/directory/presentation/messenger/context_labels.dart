// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';

/// #1824 — the words and the glyph that name a conversation's context,
/// the same in the inbox, the forward picker and the thread header.
String contextLabel(AppLocalizations? l10n, InboxEntry entry) {
  final space = entry.workspaceName;
  return switch (entry.kind) {
    MessageContextKind.space =>
      l10n?.messengerContextSpace(space) ?? 'In $space',
    MessageContextKind.account =>
      l10n?.messengerContextAccount ?? 'Person to person',
    MessageContextKind.inquiryOut =>
      l10n?.messengerContextInquiryOut(space) ?? 'Your inquiry to $space',
    MessageContextKind.inquiryIn =>
      l10n?.messengerContextInquiryIn(space) ?? 'Inquiry to $space',
  };
}

/// The label plus the server, which is named only when it is not this
/// one — a person should not need to know where a space is hosted.
String contextSubtitle(
  AppLocalizations? l10n,
  InboxEntry entry,
  Map<String, String> servers,
) {
  final label = contextLabel(l10n, entry);
  if (!entry.isRemote) return label;
  final server = servers[entry.source] ?? Uri.tryParse(entry.source)?.host;
  if (server == null || server.isEmpty) return label;
  return '$label · ${l10n?.messengerOnServer(server) ?? 'on $server'}';
}

IconData contextIcon(MessageContextKind kind) => switch (kind) {
  MessageContextKind.space => Icons.meeting_room_outlined,
  MessageContextKind.account => Icons.person_outline,
  MessageContextKind.inquiryOut => Icons.contact_support_outlined,
  MessageContextKind.inquiryIn => Icons.support_agent_outlined,
};
