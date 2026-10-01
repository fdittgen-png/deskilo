// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

class AccountPortalEntry extends StatelessWidget {
  const AccountPortalEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l?.portalDiscover ?? 'Find a workspace',
      icon: const Icon(Icons.public),
      // #1823 — Me is the account's home: gone to, not stacked.
      onSelected: (path) =>
          path == '/me' ? context.go(path) : context.push(path),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const ValueKey('portal-open-me'),
          value: '/me',
          child: Text(l?.portalOpenMe ?? 'Me: my account and my spaces'),
        ),
        PopupMenuItem(
          value: '/discover',
          child: Text(l?.portalDiscover ?? 'Find a workspace'),
        ),
        PopupMenuItem(
          value: '/account-messages',
          child: Text(l?.portalMessenger ?? 'Account messenger'),
        ),
        PopupMenuItem(
          value: '/connections',
          child: Text(l?.portalConnections ?? 'Connected servers'),
        ),
        PopupMenuItem(
          value: '/account-activity',
          child: Text(l?.accountActivityTitle ?? 'My consumption and payments'),
        ),
      ],
    );
  }
}
