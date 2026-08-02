// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/dev_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_gateway.dart';

/// Which platform environment an e-invoice send should target (#393).
///
/// Production is the only answer unless BOTH latches are open:
///  * the app's developer mode is on (Réglages → Avancé) — a normal
///    admin never sees a test choice, and
///  * the gateway probe reports a configured test environment, which it
///    can only do when the DEPLOYED function understands the parameter —
///    an older function would ignore it and send the test document to
///    the production platform, the exact accident this latch prevents.
///
/// Returns 'prod' / 'uat' / 'dev', or null when the picker was shown and
/// dismissed (the caller must NOT send).
Future<String?> pickEInvoiceEnvironment(
  BuildContext context,
  WidgetRef ref, {
  required EInvoiceGatewayConfig gateway,
}) async {
  // Await the store, not `.value`: on a cold provider the sync read is
  // still AsyncLoading and would silently answer "off".
  final devMode = await ref.read(devModeProvider.future);
  final testEnvironments = gateway.testEnvironments;
  if (!devMode || testEnvironments.isEmpty) return 'prod';
  if (!context.mounted) return null;

  final l10n = AppLocalizations.of(context);
  String label(String env) => switch (env) {
        'uat' => l10n?.einvoiceEnvUat ?? 'UAT (test platform)',
        'dev' => l10n?.einvoiceEnvDev ?? 'Dev (test platform)',
        _ => l10n?.einvoiceEnvProd ?? 'Production',
      };

  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.lgAll,
            child: Text(
              l10n?.einvoiceEnvTitle ?? 'Send to which platform?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: const ValueKey('einvoice-env-prod'),
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(label('prod')),
            subtitle: Text(
              l10n?.einvoiceEnvProdHint ?? 'The real submission.',
            ),
            onTap: () => Navigator.of(context).pop('prod'),
          ),
          for (final env in testEnvironments)
            ListTile(
              key: ValueKey('einvoice-env-$env'),
              leading: const Icon(Icons.science_outlined),
              title: Text(label(env)),
              subtitle: Text(
                l10n?.einvoiceEnvTestHint ??
                    'A rehearsal — logged as a test send.',
              ),
              onTap: () => Navigator.of(context).pop(env),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
