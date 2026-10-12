// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';

class AccountPortalEntry extends StatelessWidget {
  const AccountPortalEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('account-portal-entry-portal-discover'),
      tooltip: l.portalDiscover,
      icon: const Icon(Icons.public),
      // #1823 — Me is the account's home: gone to, not stacked.
      onSelected: (path) =>
          path == '/me' ? context.go(path) : context.push(path),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const ValueKey('portal-open-me'),
          value: '/me',
          child: Text(l.portalOpenMe),
        ),
        PopupMenuItem(
          value: '/discover',
          child: Text(l.portalDiscover),
        ),
        PopupMenuItem(
          value: '/account-messages',
          child: Text(l.portalMessenger),
        ),
        PopupMenuItem(
          value: '/connections',
          child: Text(l.portalConnections),
        ),
        PopupMenuItem(
          value: '/account-activity',
          child: Text(l.accountActivityTitle),
        ),
      ],
    );
  }
}
