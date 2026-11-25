// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the Demo's till layouts, kept in memory with the server's rules: the same validation as `till_layout_save_v1`
// (validateTillLayout, the cell cap of the settings, the items the Demo sells), the version the editor read, the request
// id that answers the same version again. The front counter starts on the Retail template; the bakery counter on the
// Bakery template with a keypad and a calculator.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/money/domain/till_layout.dart';
import '../../../features/money/domain/till_layout_port.dart';
import '../../../features/money/domain/till_layout_templates.dart';
import '../../codes/dk_code.dart';
import '../../settings/setting_defaults.g.dart';
import 'demo_stock_registry.dart';

PostgrestException _refused(String code, String message, String reason) =>
    PostgrestException(message: message, code: code, details: '{"reason":"$reason"}');

/// The Demo's front counter, laid out with the Retail template.
const _frontTill = 'demo-till-front';

/// The Demo's bakery counter, laid out with the Bakery template and a calculator.
@visibleForTesting
const demoBakeryTill = 'demo-till-bakery';

class DemoTillLayouts implements TillLayoutPort {
  DemoTillLayouts({this.maxCells = SettingDefaults.counterLayoutMaxCells, Set<String>? items})
      : _items = items ?? DemoStockRegistry.catalogue.keys.toSet();

  final int maxCells;
  final Set<String> _items;
  final Map<String, TillLayout> _drafts = {};
  final Map<String, TillLayout> _published = {};
  final Map<String, int> _answered = {};

  /// The two counters as a visitor finds them: both published, their page named in English (the Demo's own data).
  void seed() {
    String name(TillTemplatePage p) => switch (p) {
      TillTemplatePage.sale => 'Sale',
      TillTemplatePage.drinks => 'Drinks',
      TillTemplatePage.food => 'Food',
      TillTemplatePage.desk => 'Desk',
    };
    final retail = TillLayoutTemplate.retail.build('Front counter', pageName: name);
    final bakery = withCalculator(TillLayoutTemplate.bakery.build('Bakery counter', pageName: name));
    _published[_frontTill] = TillLayout(name: retail.name, pages: retail.pages, version: 1, status: TillLayoutStatus.published);
    _published[demoBakeryTill] = TillLayout(name: bakery.name, pages: bakery.pages, version: 1, status: TillLayoutStatus.published);
  }

  @override
  Future<TillLayout?> draft(String workspaceId, String tillId) async => _drafts[tillId];

  @override
  Future<TillLayout?> published(String workspaceId, String tillId) async => _published[tillId];

  @override
  Future<int> save(String workspaceId, {required String requestId, required String tillId, required TillLayout layout, required int expectedVersion}) async {
    final again = _answered[requestId];
    if (again != null) return again;
    final current = _drafts[tillId]?.version ?? 0;
    if (current != expectedVersion) throw _refused(DkCode.dkl10, 'someone changed this layout: reload it', 'version');
    final problems = validateTillLayout(layout, maxCells: maxCells, knownItems: _items);
    if (problems.isNotEmpty) throw _refused(DkCode.dkl02, 'this layout cannot be saved', problems.first.toString());
    final saved = TillLayout(name: layout.name.trim(), pages: layout.pages, version: current + 1);
    _drafts[tillId] = saved;
    return _answered[requestId] = saved.version;
  }

  @override
  Future<int> publish(String workspaceId, {required String requestId, required String tillId, required int expectedVersion}) async {
    final again = _answered[requestId];
    if (again != null) return again;
    final draft = _drafts[tillId];
    if (draft == null || draft.version != expectedVersion) throw _refused(DkCode.dkl10, 'someone changed this layout: reload it', 'version');
    final problems = validateTillLayout(draft, maxCells: maxCells, knownItems: _items);
    if (problems.isNotEmpty) throw _refused(DkCode.dkl02, 'this layout cannot be published', problems.first.toString());
    final version = (_published[tillId]?.version ?? 0) + 1;
    _published[tillId] = TillLayout(name: draft.name, pages: draft.pages, version: version, status: TillLayoutStatus.published);
    return _answered[requestId] = version;
  }
}

@visibleForTesting
/// [layout] with a calculator on the desk grid of its first page, in the first free place it fits (the bakery's).
TillLayout withCalculator(TillLayout layout) {
  final page = layout.pages.first;
  final desk = page.grids[TillLayoutSize.desk]!;
  for (var row = 0; row + TillWidgetKind.calculator.minRows <= desk.rows; row++) {
    for (var col = 0; col + TillWidgetKind.calculator.minCols <= desk.cols; col++) {
      final cell = TillCell(kindWire: TillWidgetKind.calculator.wire, col: col, row: row, colSpan: 2, rowSpan: 3);
      if (desk.cells.every((c) => !c.overlaps(cell))) {
        final grids = {...page.grids, TillLayoutSize.desk: desk.withCells([...desk.cells, cell])};
        return TillLayout(name: layout.name, version: layout.version, status: layout.status, pages: [TillPage(name: page.name, grids: grids), ...layout.pages.skip(1)]);
      }
    }
  }
  return layout;
}
