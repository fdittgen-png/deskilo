// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The assistant identity step, taken where it is shown: one tap binds the
// account to this database's identity (`finalize_identity_binding`). It
// used to open the sign-in methods page ("linked accounts"), which shows
// e-mail/Google as "linked" and has no way to take this step at all.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/identity_binding.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/mcp_providers.dart';

/// Confirms the identity, refreshes every assistant fact, and says why
/// when the server refuses.
Future<void> confirmAssistantIdentity(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  IdentityBindingStatus? result;
  await runGuarded(
    context,
    domain: 'mcp',
    message: 'identity confirmation failed',
    action: () async =>
        result = await ref.read(assistantAccessProvider).confirmIdentity(),
  );
  ref
    ..invalidate(myDatabaseCapabilitiesProvider)
    ..invalidate(mcpAccessStatusProvider)
    ..invalidate(connectedMcpOverviewProvider);
  if (!context.mounted) return;
  switch (result?.state) {
    case IdentityBindingState.ineligible:
      AppSnack.error(
        context,
        l10n?.mcpIdentityIneligible ?? 'This account cannot be confirmed yet — confirm your e-mail address or sign in with a provider first.',
      );
    case IdentityBindingState.conflict:
      AppSnack.error(
        context,
        l10n?.mcpIdentityConflict ?? 'Another account already holds this identity here — a database administrator can resolve it.',
      );
    default:
      break;
  }
}
