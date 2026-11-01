// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3226 — one editing screen per setting. The payment instructions are
// edited on `/payment-methods` and, framed with a live preview and the
// step's server draft, on the setup guide's own step; both draw the same
// fields (`PaymentInstructionsFields`) and save through the one command
// (`SavePaymentInstructions`). Anywhere else that saves them is a second
// editor: the Settings row and the drawer entry only link.
import 'dart:io';

import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _owners = {
  'lib/features/workspace/application/save_payment_instructions.dart',
  'lib/features/workspace/application/save_payment_instructions.g.dart',
  'lib/features/workspace/presentation/screens/payment_methods_screen.dart',
  'lib/features/workspace/presentation/widgets/setup_payment_methods_step.dart',
};

void main() {
  test('only the two editors save payment instructions', () {
    final users = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
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

  // Documents and Reports (#3226 items 2 and 3): the drawer, Settings and the
  // member's Finances all open the one screen, and say its name the same way.
  test('the library has one name wherever it is opened, in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.moneyDocumentLibrary,
        l10n.documentsTitle,
        reason:
            '${locale.languageCode}: the member door and the library '
            'screen must read the same',
      );
    }
  });

  test(
    'every library door opens /documents and every reports door /reports',
    () {
      String read(String p) => File(p).readAsStringSync();
      expect(
        read('lib/features/money/presentation/widgets/documents_face.dart'),
        contains("context.push('/documents')"),
      );
      expect(
        read('lib/features/profile/presentation/screens/settings_screen.dart'),
        contains("context.push('/documents')"),
      );
      expect(
        read(
          'lib/features/profile/presentation/widgets/settings_workspace_sections.dart',
        ),
        contains("context.push('/reports')"),
      );
      expect(
        read(
          'lib/features/workspace/presentation/screens/workspace_settings_parameters.dart',
        ),
        contains("context.push('/reports')"),
      );
    },
  );
}
