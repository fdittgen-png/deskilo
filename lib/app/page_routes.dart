// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — the pages one screen opens over another, each a route with a
// path (they were `Navigator.push`es the router, the route policy and the
// route registry could not see). The router registers them from here.
import '../core/navigation/page_spec.dart';
import '../features/directory/presentation/directory_pages.dart';
import '../features/help/presentation/screens/help_screen.dart'
    show supportBundlePage;
import '../features/money/presentation/screens/my_finances_screen.dart'
    show accountActivityPage;
import '../features/money/presentation/widgets/expense_repartition_sheet.dart'
    show expenseRepartitionPage;
import '../features/money/presentation/widgets/settlement_sheet.dart'
    show settlementPage;
import '../features/profile/presentation/screens/server_choice_screen.dart'
    show newInstanceFromChoicePage;
import '../features/task_recorder/presentation/recorder_pages.dart';
import '../features/workspace/presentation/workspace_pages.dart';

/// Every page opened over another screen.
final List<PageSpec<Object?>> openedPages = [
  ...directoryPages,
  ...workspacePages,
  ...recorderPages,
  expenseRepartitionPage,
  settlementPage,
  accountActivityPage,
  supportBundlePage,
  newInstanceFromChoicePage,
];
