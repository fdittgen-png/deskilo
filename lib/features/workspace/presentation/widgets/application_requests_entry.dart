// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

class ApplicationRequestsEntry extends StatelessWidget {
  const ApplicationRequestsEntry({super.key, this.compact = true});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final label =
        AppLocalizations.of(context)?.applicationsTitle ?? 'Workspace requests';
    void open() => context.push('/applications');
    return compact
        ? IconButton(
            key: const ValueKey('workspace-requests'),
            tooltip: label,
            onPressed: open,
            icon: const Icon(Icons.assignment_ind_outlined),
          )
        : TextButton.icon(
            key: const ValueKey('workspace-requests'),
            onPressed: open,
            icon: const Icon(Icons.assignment_ind_outlined),
            label: Text(label),
          );
  }
}
