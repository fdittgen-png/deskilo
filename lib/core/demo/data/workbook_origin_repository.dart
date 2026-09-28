// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/workbook_origin.dart';

class FakeWorkbookOriginRepository implements WorkbookOriginRepository {
  WorkbookOrigin origin = const WorkbookOrigin(sourceId: 'demo-synthetic',
    installationId: 'demo-synthetic', accountId: 'demo-persona');
  @override
  Future<WorkbookOrigin> read() async => origin;
}
