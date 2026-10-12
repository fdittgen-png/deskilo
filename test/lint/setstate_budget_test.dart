// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — screen state belongs in a notifier, not in `setState`: form,
// selection and async-call state in the widget cannot be tested without
// pumping the whole screen and does not survive a rebuild of the parent.
// `setState` stays for ephemeral layout state (expanded, hover).
//
// The issue asked for no screen over 5 `setState` calls. Measured on
// 2026-10-11: 55 files are over 5, with 501 calls between them; moving
// each screen's state into a notifier is a rewrite of that screen, done
// when the screen is next changed. Until then this holds the line: no
// file outside the list grows past 5, and no listed file grows at all —
// lower or remove its entry when it moves.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/layering/analysis.dart' show libraryPathOf;
import 'lint_sources.dart';

/// Files over 5 `setState` calls on 2026-10-11, with their count then.
const Map<String, int> _overBudget = {
  // A library whose parts were each within 5 before #2386 counted them
  // together.
  'lib/features/profile/presentation/screens/settings_screen.dart': 6,
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart':
      29,
  'lib/features/profile/presentation/screens/new_instance_screen.dart': 22,
  'lib/features/workspace/presentation/screens/onboarding_screen.dart': 16,
  'lib/features/calendar/presentation/screens/calendar_hub_screen.dart': 15,
  'lib/features/money/presentation/screens/billing_screen.dart': 14,
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 14,
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 13,
  'lib/features/events/presentation/widgets/policy_editor_sheet.dart': 13,
  'lib/features/mcp/presentation/eligibility_review_screen.dart': 12,
  'lib/features/money/presentation/screens/repartition_wizard_screen.dart': 12,
  'lib/features/money/presentation/widgets/expense_repartition_sheet.dart': 12,
  'lib/features/workspace/presentation/screens/colours_screen.dart': 11,
  'lib/features/directory/presentation/directory_screen.dart': 11,
  'lib/features/money/presentation/widgets/invoice_template_sheet.dart': 11,
  'lib/features/reservations/presentation/widgets/booking_sheet.dart': 10,
  'lib/features/workspace/presentation/widgets/question_editor_sheet.dart': 10,
  'lib/features/workspace/presentation/widgets/holiday_import_sheet.dart': 10,
  'lib/features/money/presentation/widgets/book_profile_sheet.dart': 10,
  'lib/features/workspace/presentation/widgets/template_gallery.dart': 9,
  'lib/features/workspace/presentation/widgets/invitation_join_panel.dart': 9,
  'lib/features/directory/presentation/public_page_editor.dart': 9,
  'lib/features/task_recorder/presentation/guide_host/guide_host.dart': 9,
  'lib/features/money/presentation/screens/legal_identity_screen.dart': 9,
  'lib/features/reservations/presentation/widgets/space_scan.dart': 8,
  'lib/features/mcp/presentation/mcp_consent_screen.dart': 8,
  'lib/features/directory/presentation/connect_with_identity_sheet.dart': 8,
  'lib/features/money/presentation/widgets/book_chart_sheet.dart': 8,
  'lib/features/auth/presentation/screens/auth_screen.dart': 7,
  'lib/features/auth/presentation/widgets/badge_pin_tile.dart': 7,
  'lib/features/workspace/presentation/widgets/public_holidays_sheet.dart': 7,
  'lib/features/directory/presentation/connection_dialog.dart': 7,
  'lib/features/directory/presentation/messenger/create_group_screen.dart': 7,
  'lib/features/directory/presentation/messenger/context_thread_screen.dart': 7,
  'lib/features/money/presentation/screens/vat_screen.dart': 7,
  'lib/features/money/presentation/screens/number_sequences_screen.dart': 7,
  'lib/features/money/presentation/widgets/invoice_form_sheet.dart': 7,
  'lib/features/money/presentation/widgets/settlement_sheet.dart': 7,
  'lib/features/help/presentation/screens/support_bundle_screen.dart': 7,
  'lib/features/auth/presentation/widgets/badge_sign_in_sheet.dart': 6,
  'lib/features/reservations/presentation/widgets/space_act_form.dart': 6,
  'lib/features/workspace/presentation/screens/template_compare_screen.dart': 6,
  'lib/features/workspace/presentation/screens/deployment_screen.dart': 6,
  'lib/features/workspace/presentation/widgets/ref_picker_sheet.dart': 6,
  'lib/features/workspace/presentation/widgets/process_change_sheet.dart': 6,
  'lib/features/workspace/presentation/widgets/save_template_sheet.dart': 6,
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': 6,
  'lib/features/workspace/presentation/widgets/conversation_thread.dart': 6,
  'lib/features/mcp/presentation/mcp_policy_screen.dart': 6,
  'lib/features/directory/presentation/directory_link_dialog.dart': 6,
  'lib/features/profile/presentation/screens/developer_screen.dart': 6,
  'lib/features/profile/presentation/widgets/backend_candidate_form.dart': 6,
  'lib/features/money/presentation/widgets/register_payment_sheet.dart': 6,
  'lib/features/money/presentation/widgets/dunning_rules_dialog.dart': 6,
  'lib/features/money/presentation/widgets/billing_rules_dialog.dart': 6,
  'lib/features/kiosk/presentation/widgets/kiosk_act_sheet.dart': 6,
};

void main() {
  test('setState: no new screen over 5, no listed screen grows', () {
    // #2386 — counted per library: a screen split across part files is
    // one screen, and `_update(` is its setState seen from a part.
    final call = RegExp(r'\b(setState|_update)\(');
    final counts = <String, int>{};
    for (final file in handWrittenDartFiles('lib')) {
      final count = scanLines(
        [file],
        (l) => call.hasMatch(l) && !l.contains('void _update('),
      ).length;
      if (count == 0) continue;
      final library = libraryPathOf(file);
      counts[library] = (counts[library] ?? 0) + count;
    }
    final grown = <String>[];
    final shrunk = <String>[];
    for (final MapEntry(key: path, value: count) in counts.entries) {
      final allowed = _overBudget[path] ?? 5;
      if (count > allowed) grown.add('$path: $count (allowed $allowed)');
      final listed = _overBudget[path];
      if (listed != null && count < listed) {
        shrunk.add('$path: $count (listed $listed)');
      }
    }
    expect(
      grown,
      isEmpty,
      reason: 'move the state into a notifier:\n${grown.join('\n')}',
    );
    expect(
      shrunk,
      isEmpty,
      reason:
          'lower (or remove, at 5 or fewer) the entry:\n'
          '${shrunk.join('\n')}',
    );
  });
}
