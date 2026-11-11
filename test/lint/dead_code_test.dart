// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2383 — no dead code in `lib/`. A public top-level declaration that
// nothing references, or that only tests reference, fails here unless the
// list below names it with the issue that decides its fate. The scan is
// `tool/dead_code.dart` (run it to see every finding); this file is the
// gate.
//
// The list only shrinks: an entry the scan no longer reports fails too,
// so a symbol wired in or deleted takes its line out with it. The first
// scan found dead and test-only declarations in every layer; without a
// gate the list regrows.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dead_code/scan.dart';

/// `path::name` → why it stays, naming the issue that resolves it.
const Map<String, String> _allowed = {
  'lib/core/ui/kit/result_page.dart::ResultPage':
      '#3587 R1-d/R1-e/R1-f — the invoice page and the flows read it',
  'lib/core/ui/kit/select_row.dart::SelectRow':
      '#3587 R1-d/R1-e/R1-f — the invoice page and the flows read it',
  // The workbook's sources as data: the export coverage lint reads them now,
  // the about-this-export sheet will list them for the operator.
  'lib/features/workspace/domain/workspace_export_sources.dart::workspaceExportSources':
      '#2861 — the about sheet names each source and what it leaves out',
  // The countries the store holds rates for: the unchanged vat_versions_test
  // walks them (it did before the move, over the constant it replaced).
  'lib/features/money/domain/vat_catalogue.dart::vatCatalogueCountries':
      '#2478 — read by vat_versions_test, which pins every country\'s seed',
  // Every form the app fills, resolved against the store: the unchanged
  // vat_forms_test walks it (the field it was before 0432 was read by lib).
  // Spanish Verifactu: built and pinned before its register exists.
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuLegend':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuMention':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuCancellationHuella':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuRecordFor':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuChainHolds':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuQrUrl':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',
  'packages/deskilo_jurisdiction_es/lib/src/verifactu.dart::verifactuRecordXml':
      '#2358 — the Verifactu register slice (chain table, PDF legend and QR) wires it',

  // Domain rules the app was meant to use and does not yet.
  'packages/deskilo_money_kernel/lib/src/accounting_amount.dart::settleForeign':
      '#2365 — the accounting engine',
  'lib/features/money/domain/accounting_tax.dart::projectTax':
      '#2365 — the accounting engine',
  'lib/features/money/domain/accounting_tax.dart::splitDeductible':
      '#2365 — input VAT, the deductible share',
  'lib/features/money/domain/accounting_tax.dart::taxDueOn':
      '#2365 — the accounting engine',
  'packages/deskilo_money_kernel/lib/src/book_profile.dart::authorityOn':
      '#2365 — the book chart wired in',
  'lib/features/money/domain/posting_preview.dart::previewInvoicePosting':
      '#2365 — the server-side posting engine',
  'lib/features/money/domain/posting_preview.dart::previewPaymentPosting':
      '#2365 — the server-side posting engine',
  'lib/features/money/application/declare_vat.dart::vatDeclarationDraft':
      '#2357 — the Dart side of the VAT return',
  'lib/features/money/domain/vat_declaration_build.dart::computeVatDeclarationLines':
      '#2357 — the VAT return',
  'packages/deskilo_invoice_model/lib/src/vat_rate.dart::vatPercentAt':
      '#2356 — dated rates, the twin of vat_rate_percent_at',
  'packages/deskilo_invoice_model/lib/src/vat_rate.dart::vatGroupForPercent':
      '#2356 — Z/E categories',

  // Contracts the tests are the reader of: a bound, a measured table, a
  // registry's server copy, or a guard run over a registry. They stay
  // beside the data they describe.
  'lib/features/workspace/domain/holiday_import.dart::holidaySourceCoverage':
      '#2051 — measured coverage, pinned to the country catalogue',
  'lib/features/workspace/domain/kpi_contract.dart::kpiRegistryJson':
      '#1921 — the source kpi_registry_sql_test holds the server to',
  'lib/features/workspace/domain/feature_lifecycle.dart::validateFeatureAssessments':
      '#1850 — registry guard over featureAssessments',
  'lib/features/workspace/domain/feature_lifecycle.dart::featureMaturityFromName':
      '#1850 — reads a maturity from the evidence ledger',
  'lib/features/workspace/domain/feature_lifecycle.dart::featureLifecycleFromName':
      '#1850 — reads a lifecycle from the evidence ledger',
  'lib/features/workspace/domain/feature_assessment_evidence.dart::validateAssessmentsAgainstLedger':
      '#1850 — registry guard against the evidence ledger',
  'lib/features/workspace/domain/feature_assessment_evidence.dart::validatePromotions':
      '#1850 — registry guard over promotions',
  'lib/features/workspace/domain/feature_assessment_evidence.dart::evidenceStandingFromName':
      '#1850 — reads a standing from the release artifact',
  'lib/features/workspace/domain/feature_operation.dart::featureOperationAllowed':
      "#1851 — the Dart statement of the server's operation rule",
  'lib/features/workspace/domain/feature_operation.dart::featureOperationFromWire':
      "#1851 — the Dart statement of the server's operation rule",
};

void main() {
  final findings = scanDeadCode(Directory.current.path);

  test('no public declaration in lib/ is dead or only used by tests', () {
    final fresh = [
      for (final f in findings)
        if (!_allowed.containsKey(f.key)) f.toString(),
    ];
    expect(
      fresh,
      isEmpty,
      reason:
          'delete it, move a test-only helper to test/helpers/, or '
          'name the issue that wires it in, in _allowed:\n'
          '${fresh.join('\n')}',
    );
  });

  test('every allowed entry is still a finding — the list only shrinks', () {
    final found = {for (final f in findings) f.key};
    final stale = [
      for (final key in _allowed.keys)
        if (!found.contains(key)) key,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'no longer dead — remove the entry:\n${stale.join('\n')}',
    );
  });

  test('every allowed entry names the issue that resolves it', () {
    final unnamed = [
      for (final e in _allowed.entries)
        if (!RegExp(r'#\d+').hasMatch(e.value)) e.key,
    ];
    expect(unnamed, isEmpty);
  });

  group('the scan', () {
    late Directory root;
    late List<DeadCodeFinding> found;

    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUpAll(() {
      root = Directory.systemTemp.createTempSync('dead_code');
      write('lib/a.dart', '''
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'a.g.dart';

void unusedThing() => unusedThing();

int onlyTested() => 1;

class Box {
  const Box();
  Box copy() => const Box();
}

@riverpod
int counter(Ref ref) => 0;

int usedHere() => 2;
int user() => usedHere();

extension Shout on String {
  String get shout => toUpperCase();
}

const sql = r\'\'\'
select current_setting('x')
\'\'\';

@pragma('vm:entry-point')
void backgroundHandler() {}
''');
      write('lib/a.g.dart', '''
part of 'a.dart';
final counterProvider = 0; // Box, unusedThing
''');
      write('lib/b.dart', '''
// unusedThing is only named in a comment.
import 'a.dart';
int read() => counterProvider + user() + sql.length;
''');
      write('test/a_test.dart', '''
import 'package:x/a.dart';
void main() => onlyTested();
''');
      // #3376: a scanned package is checked like lib/, an unlisted one is not.
      write('packages/deskilo_money_kernel/lib/k.dart', '''
int kernelUnused() => 1;
int kernelUsed() => 2;
''');
      write('packages/other_package/lib/o.dart', '''
int otherUnused() => 1;
''');
      write('lib/uses_kernel.dart', '''
import 'package:deskilo_money_kernel/k.dart';
int use() => kernelUsed();
''');
      found = scanDeadCode(root.path);
    });

    tearDownAll(() => root.deleteSync(recursive: true));

    DeadCodeKind? kindOf(String name) =>
        found.where((f) => f.name == name).firstOrNull?.kind;

    test('an unreferenced public function is found', () {
      expect(
        kindOf('unusedThing'),
        DeadCodeKind.unreferenced,
        reason:
            'a recursive call, a comment and a generated part are '
            'not references',
      );
    });

    test('an unused function of any package is found, a used one is not', () {
      expect(kindOf('kernelUnused'), DeadCodeKind.unreferenced);
      expect(kindOf('kernelUsed'), isNull);
      expect(kindOf('otherUnused'), DeadCodeKind.unreferenced);
    });

    test('a function only a test calls is found', () {
      expect(kindOf('onlyTested'), DeadCodeKind.testOnly);
    });

    test('a class naming itself is still unreferenced', () {
      expect(kindOf('Box'), DeadCodeKind.unreferenced);
    });

    test('what is used is not listed', () {
      expect(
        kindOf('counter'),
        isNull,
        reason: 'a Riverpod function is used through its provider',
      );
      expect(
        kindOf('usedHere'),
        isNull,
        reason: 'used by another declaration of its own file',
      );
      expect(
        kindOf('Shout'),
        isNull,
        reason: 'an extension is used through its members',
      );
      expect(
        kindOf('current_setting'),
        isNull,
        reason: 'a string never declares anything',
      );
      expect(
        kindOf('backgroundHandler'),
        isNull,
        reason: 'an entry point is called by the engine',
      );
    });

    test('it reports exactly those', () {
      expect(found.map((f) => f.name).toSet(), {
        'unusedThing',
        'onlyTested',
        'Box',
        'read', // lib/b.dart's own function, which nothing calls
        'use', // lib/uses_kernel.dart's own function, which nothing calls
        'kernelUnused', // a package (#3376)
        'otherUnused', // any package (#3401)
      });
    });
  });
}
