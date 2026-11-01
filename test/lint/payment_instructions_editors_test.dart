// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3226 — one editing screen per setting. The payment instructions are
// edited on `/payment-methods` and, framed with a live preview and the
// step's server draft, on the setup guide's own step; both draw the same
// fields (`PaymentInstructionsFields`) and save through the one command
// (`SavePaymentInstructions`). Anywhere else that saves them is a second
// editor: the Settings row and the drawer entry only link.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _owners = {
  'lib/features/workspace/application/save_payment_instructions.dart',
  'lib/features/workspace/application/save_payment_instructions.g.dart',
  'lib/features/workspace/presentation/screens/payment_methods_screen.dart',
  'lib/features/workspace/presentation/widgets/setup_payment_methods_step.dart',
};

void main() {
  test('only the two editors save payment instructions', () {
    final users = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (_owners.contains(path)) continue;
      if (f.readAsStringSync().contains('savePaymentInstructionsProvider')) {
        users.add(path);
      }
    }
    expect(
      users,
      isEmpty,
      reason:
          'a third editor of the payment instructions: link to '
          '/payment-methods instead',
    );
  });

  test('the Settings row and the drawer entry link to the one screen', () {
    final settings = File(
      'lib/features/workspace/presentation/screens/'
      'workspace_settings_parameters.dart',
    ).readAsStringSync();
    expect(settings, contains("context.push('/payment-methods')"));
    final drawer = File('lib/app/shell/shell_drawer_entries.dart')
        .readAsStringSync();
    expect(drawer, contains("go('/payment-methods')"));
  });
}
