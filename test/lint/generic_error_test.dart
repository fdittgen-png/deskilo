// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S2 — "Something went wrong. Please try again." may only become rarer.
//
// `workspaceGenericError` is the sentence a screen falls back to when it
// has nothing better to say. Measured on master 2026-09-16: **182** uses in
// **86** files. Most are honest fallbacks behind `runGuarded`, which
// since #1305 answers the refusals any screen can meet — no permission, no
// session, already decided, changed meanwhile — and #1241's dropped
// connection before the fallback is ever shown. What remains is where a
// domain knows its own refusals and has not named them yet.
//
// Same mechanism as `state_primitives_test`: per file, down only. A file
// that names its failures properly lowers its entry in the same commit.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Files still falling back to the generic sentence → how many times.
const Map<String, int> _baseline = {
  'lib/core/i18n/regional_formats_section.dart': 1,
  'lib/core/trace/guarded.dart': 1,
  'lib/features/auth/presentation/screens/linked_accounts_screen.dart': 1,
  'lib/features/calendar/presentation/screens/calendar_hub_screen.dart': 1,
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 1,
  'lib/features/calendar/presentation/widgets/access_sheet.dart': 2,
  'lib/features/editor/presentation/screens/editor_screen.dart': 2,
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 4,
  'lib/features/events/presentation/screens/events_screen.dart': 1,
  // #1306 — moved with the pending decisions out of events_screen.dart.
  'lib/features/events/presentation/widgets/pending_decisions_section.dart': 1,
  'lib/features/events/presentation/screens/validation_settings_screen.dart': 2,
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 2,
  'lib/features/members/presentation/member_profile_link.dart': 1,
  'lib/features/members/presentation/screens/directory_screen.dart': 2,
  'lib/features/members/presentation/screens/managed_profile_screen.dart': 1,
  'lib/features/members/presentation/screens/member_page.dart': 3,
  'lib/features/members/presentation/widgets/managed_access_editor.dart': 1,
  'lib/features/money/presentation/accounting_export.dart': 7,
  'lib/features/money/presentation/invoice_actions.dart': 11,
  'lib/features/money/presentation/report_actions.dart': 2,
  'lib/features/money/presentation/screens/billing_screen.dart': 2,
  'lib/features/money/presentation/screens/einvoice_config_screen.dart': 2,
  'lib/features/money/presentation/screens/invoice_register_screen.dart': 1,
  'lib/features/money/presentation/screens/legal_identity_screen.dart': 1,
  'lib/features/money/presentation/screens/money_screen.dart': 6,
  'lib/features/money/presentation/screens/number_sequences_screen.dart': 1,
  'lib/features/money/presentation/screens/payment_config_screen.dart': 3,
  'lib/features/money/presentation/screens/repartition_wizard_screen.dart': 1,
  'lib/features/money/presentation/screens/report_editor_screen.dart': 1,
  'lib/features/money/presentation/screens/services_screen.dart': 2,
  'lib/features/money/presentation/screens/vat_declarations_screen.dart': 5,
  'lib/features/money/presentation/screens/vat_screen.dart': 1,
  'lib/features/money/presentation/widgets/billing_rules_dialog.dart': 1,
  'lib/features/money/presentation/widgets/consumption_sheet.dart': 1,
  'lib/features/money/presentation/widgets/dunning_rules_dialog.dart': 1,
  'lib/features/money/presentation/widgets/expense_repartition_sheet.dart': 1,
  'lib/features/money/presentation/widgets/expense_schedule_sheet.dart': 3,
  'lib/features/money/presentation/widgets/expense_sheet.dart': 1,
  'lib/features/money/presentation/widgets/invoice_archive_tab.dart': 1,
  'lib/features/money/presentation/widgets/invoice_form_sheet.dart': 1,
  'lib/features/money/presentation/widgets/invoice_template_sheet.dart': 2,
  'lib/features/money/presentation/widgets/negotiation_card.dart': 1,
  'lib/features/money/presentation/widgets/payment_terms_card.dart': 1,
  'lib/features/money/presentation/widgets/register_payment_sheet.dart': 1,
  'lib/features/money/presentation/widgets/report_image_picker.dart': 1,
  'lib/features/money/presentation/widgets/settlement_sheet.dart': 1,
  'lib/features/money/presentation/widgets/usage_face.dart': 3,
  'lib/features/money/presentation/widgets/wizard_steps_issue.dart': 1,
  'lib/features/money/presentation/widgets/wizard_steps_payments.dart': 1,
  'lib/features/plan/presentation/screens/accessories_screen.dart': 2,
  'lib/features/plan/presentation/widgets/admin_seat_actions.dart': 1,
  'lib/features/profile/presentation/screens/backend_screen.dart': 1,
  'lib/features/profile/presentation/screens/consent_screen.dart': 1,
  'lib/features/profile/presentation/screens/developer_screen.dart': 2,
  'lib/features/profile/presentation/screens/personal_info_screen.dart': 2,
  'lib/features/profile/presentation/screens/privacy_screen.dart': 2,
  'lib/features/profile/presentation/screens/settings_screen.dart': 2,
  'lib/features/reservations/presentation/reserve_seat_actions.dart': 3,
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 1,
  'lib/features/reservations/presentation/widgets/reservation_detail_sheet.dart': 2,
  'lib/features/reservations/presentation/widgets/space_act_sheet.dart': 1,
  'lib/features/reservations/presentation/widgets/space_scan.dart': 4,
  'lib/features/workspace/presentation/excel_export.dart': 1,
  'lib/features/workspace/presentation/member_admin_actions.dart': 13,
  'lib/features/workspace/presentation/member_vat_treatment.dart': 1,
  'lib/features/workspace/presentation/screens/availability_screen.dart': 2,
  'lib/features/workspace/presentation/screens/deployment_screen.dart': 3,
  'lib/features/workspace/presentation/screens/documents_screen.dart': 3,
  'lib/features/workspace/presentation/screens/features_screen.dart': 1,
  'lib/features/workspace/presentation/screens/members_screen.dart': 1,
  'lib/features/workspace/presentation/screens/messages_screen.dart': 2,
  'lib/features/workspace/presentation/screens/nfc_config_screen.dart': 1,
  'lib/features/workspace/presentation/screens/onboarding_screen.dart': 1,
  'lib/features/workspace/presentation/screens/payment_methods_screen.dart': 1,
  'lib/features/workspace/presentation/screens/roles_screen.dart': 1,
  'lib/features/workspace/presentation/screens/sites_screen.dart': 2,
  'lib/features/workspace/presentation/screens/wording_screen.dart': 2,
  'lib/features/workspace/presentation/screens/workspace_code_screen.dart': 1,
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart': 8,
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': 6,
  'lib/features/workspace/presentation/widgets/conversation_thread.dart': 1,
  'lib/features/workspace/presentation/widgets/environment_tile.dart': 2,
  'lib/features/workspace/presentation/widgets/group_info_sheet.dart': 3,
  'lib/features/workspace/presentation/widgets/member_note_actions.dart': 2,
  'lib/features/workspace/presentation/widgets/new_conversation_sheet.dart': 1,
  'lib/features/workspace/presentation/widgets/open_conversation.dart': 1,
  'lib/features/workspace/presentation/widgets/public_holidays_sheet.dart': 2,
};

void main() {
  test('no file grows a generic-error fallback (#1305)', () {
    final problems = <String>[];
    final seen = <String>{};
    for (final file in handWrittenDartFiles('lib')) {
      final n = 'workspaceGenericError'
          .allMatches(file.readAsStringSync())
          .length;
      if (n == 0) continue;
      seen.add(file.path);
      final allowed = _baseline[file.path] ?? 0;
      if (n > allowed) {
        problems.add('${file.path}: $n, baseline $allowed — grew. Say what '
            'failed: a domain refusal gets its own sentence (see '
            'bookingErrorText), a generic refusal is already answered by '
            'runGuarded.');
      } else if (n < allowed) {
        problems.add('${file.path}: $n, baseline $allowed — lower it here');
      }
    }
    for (final path in _baseline.keys) {
      if (!seen.contains(path)) problems.add('$path: none left — delete it');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
