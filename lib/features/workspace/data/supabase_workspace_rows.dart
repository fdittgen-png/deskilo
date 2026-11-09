// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the row helpers the workspace mixins share: the guarded row
// update and the row -> model mappings.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace.dart';

mixin SupabaseWorkspaceRows {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  /// Every write to a `workspaces` row goes through here (#1269).
  ///
  /// `workspaces_update` is owner-only, and an UPDATE that RLS refuses
  /// does not raise — it matches no rows, silently. The settings form
  /// then said "Workspace saved." over a row that had not moved, and
  /// reopening it showed the old value. Reading the id back is what
  /// turns a refusal into an error the caller can show.
  Future<void> updateWorkspaceRow(
    String workspaceId,
    Map<String, Object?> values,
  ) async {
    final rows = await client
        .from('workspaces')
        .update(values)
        .eq('id', workspaceId)
        .select('id');
    if (rows.isEmpty) {
      throw StateError(
        'workspace $workspaceId not updated: the row is invisible, or '
        'workspaces_update refused the write (owners and active '
        'co-owners only)',
      );
    }
  }

  /// The stored birth record; empty on a server from before the column.
  String networkIdOf(Map<String, Object?> row) =>
      row['network_id'] as String? ?? '';
  Workspace workspaceFromRow(Map<String, dynamic> row) => Workspace(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    name: row['name'] as String,
    countryCode: row['country_code'] as String,
    currencyCode: row['currency_code'] as String,
    timezone: row['timezone'] as String,
    inviteCode: row['invite_code'] as String,
    featureFlags: row['feature_flags'] as Map<String, dynamic>? ?? const {},
    rolePermissions:
        row['role_permissions'] as Map<String, dynamic>? ?? const {},
    branding: row['branding'] as Map<String, dynamic>? ?? const {},
    devMode: row['dev_mode'] as bool? ?? false,
    // #917 — a row without the column is a space that predates
    // 0160, and those are development spaces.
    environment: row['environment'] as String? ?? 'dev',
    pairId: row['pair_id'] as String? ?? '',
    networkId: networkIdOf(row),
    paymentInstructions:
        row['payment_instructions'] as Map<String, dynamic>? ?? const {},
    whatsappGroup: row['whatsapp_group'] as String? ?? '',
    address: row['address'] as String? ?? '',
    deskOpacity: (row['desk_opacity'] as num?)?.toInt() ?? 100,
    invitationTemplate: row['invitation_template'] as String? ?? '',
    vatRegime: row['vat_regime'] as String? ?? 'not_subject',
    vatId: row['vat_id'] as String? ?? '',
    legalId: row['legal_id'] as String? ?? '',
    taxExemptionReason: row['tax_exemption_reason'] as String? ?? '',
    street: row['street'] as String? ?? '',
    city: row['city'] as String? ?? '',
    postalCode: row['postal_code'] as String? ?? '',
    vatAccount: row['vat_account'] as String? ?? '',
    subscriptionVatRateId: row['subscription_vat_rate_id'] as String? ?? '',
    invoiceLegal: row['invoice_legal'] as Map<String, dynamic>? ?? const {},
    defaultLocale: row['default_locale'] as String? ?? '',
    invitationTemplates:
        row['invitation_templates'] as Map<String, dynamic>? ?? const {},
  );
}
