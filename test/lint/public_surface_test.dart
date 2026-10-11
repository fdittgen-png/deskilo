// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2384 — no over-exposed declaration in `lib/`. A public top-level
// declaration that no other production file names is `_private` to its
// file; one that tests also read carries `@visibleForTesting`. The scan is
// the dead-code scan's second mode (`tool/dead_code/surface.dart`;
// `dart run tool/dead_code.dart --surface` prints every finding); this
// file is the gate, and the analyzer's `library_private_types_in_public_api`
// keeps a private type out of a public signature.
//
// The list only shrinks: an entry the scan no longer reports fails too.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dead_code/scan.dart';

/// `path::name` → why it stays public, naming the issue that resolves it.
const Map<String, String> _allowed = {
  // The task recorder has work in progress; resolve these once it lands.
  'lib/features/task_recorder/data/recorder_store.dart::recorderLogVersion':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/data/recorder_store.dart::RecorderStoreFull':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/export/docx_output_generator.dart::outputLocalizations':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/export/task_document.dart::documentLanguageTag':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/guide/guide_codec.dart::encodeGuideStep':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/package/storyboard_review.dart::storyboardReviewFormat':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/package/storyboard_review.dart::storyboardReviewVersion':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/package/task_package.dart::taskPackageFormat':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/package/task_package.dart::taskPackageVersion':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/package/task_package.dart::taskPackageMediaTypes':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/guide_host/guide_attention.dart::guidePulseCycles':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/recorder_labels.dart::valueLabel':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/recorder_labels.dart::fieldLabel':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/recorder_labels.dart::uiTargetText':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/recorder_seam.dart::observeTaskCommand':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/presentation/widgets/task_outputs_section.dart::outputKindLabel':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/providers/recorder_providers.dart::currentRecordingPlatform':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/application/booking_observation.dart::refusalCategory':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/data/recorder_store.dart::recoverRecordingLog':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/registry_admin.dart::workspacePermissionKeys':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/registry_admin.dart::validationRuleKeys':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/registry_calendar.dart::calendarKindKeys':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/safe_payload.dart::withheldValue':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/safe_payload.dart::safeFields':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/domain/task_recording_codec.dart::encodeRecording':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/export/docx/docx_writer.dart::DocxRelationship':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/export/docx/docx_writer.dart::docxRelationshipsXml':
      '#2384 — task recorder, after the work in progress there lands',
  'lib/features/task_recorder/export/docx/docx_writer.dart::escapeXml':
      '#2384 — task recorder, after the work in progress there lands',

  // Files the open VAT branches (#2354, #2357) change; resolve these
  // once they merge.
  'lib/core/backend/backend_key.dart::jwtClaims':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/demo_scope.dart::kDemoInstallationId':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/presentation/demo_entry_sheet.dart::showDemoEntrySheet':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/seed/demo_network_seed.dart::demoNeighbourQuai':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/seed/demo_network_seed.dart::demoQuaiHosts':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/seed/demo_network_seed.dart::demoNeighbourHalles':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/demo/seed/demo_network_seed.dart::demoOwnCard':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/report_layout/pdf_geometry.dart::mmPt':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/report_layout/pdf_geometry.dart::a4HeightPt':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/presentation/widgets/invoice_form_sheet.dart::invoiceMissingLabel':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/presentation/widgets/vat_rate_field.dart::vatRateOption':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/application/pending_invitation.dart::SecurePendingInvitationStore':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/conversation.dart::conversationKindFromWire':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/feature_lifecycle.dart::featureAssessmentSchemaVersion':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::KpiDefinition':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::maxExactMinor':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/member_note_refs.dart::quoteTokenRaw':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/backend/backend_key.dart::backendKeyMaxLength':
      '#2384 — on an open VAT branch, after it merges',
  'lib/core/vat/place_of_supply.dart::euCountryCode':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/events/providers/attention_providers.dart::PrefsUpdateSeenStore':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/report_kind.dart::fixedReportKinds':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/report_layout/pdf_geometry.dart::pageStreams':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/vat_tax_point.dart::taxPointsOf':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/vat_tax_point.dart::frozenTaxPointBasis':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/money/domain/vat_tax_point.dart::paymentsOf':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/badge_pdf.dart::badgeSheetColumns':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/badge_pdf.dart::badgeSheetRows':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::KpiDisclosure':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::seatUtilisationKpi':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::invoicedKpi':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::collectedKpi':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::kpiCatalogue':
      '#2384 — on an open VAT branch, after it merges',
  'lib/features/workspace/domain/kpi_contract.dart::exactMinor':
      '#2384 — on an open VAT branch, after it merges',
};

void main() {
  final findings = scanPublicSurface(Directory.current.path);

  test('no public declaration in lib/ is used only by its own file', () {
    final fresh = [
      for (final f in findings)
        if (!_allowed.containsKey(f.key)) f.toString(),
    ];
    expect(
      fresh,
      isEmpty,
      reason:
          'make an ownFile symbol private (_name); give a testsOnly '
          'symbol @visibleForTesting; or name the issue in _allowed:\n'
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
      reason: 'no longer over-exposed — remove the entry:\n${stale.join('\n')}',
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
    late List<SurfaceFinding> found;

    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUpAll(() {
      root = Directory.systemTemp.createTempSync('public_surface_');
      write('lib/a.dart', '''
import 'package:meta/meta.dart';

part 'a.g.dart';

const ownLimit = 3;
int clamp(int v) => v > ownLimit ? ownLimit : v;

const readByTest = 4;
int twice() => readByTest * 2;

@visibleForTesting
const annotated = 5;
int thrice() => annotated * 3;

class Row {
  const Row([this.cell = const Cell()]);
  final Cell cell;
}

class Cell {
  const Cell();
}

class Sheet {
  const Sheet();
}
Object showSheet() => const Sheet();

@riverpod
int counter(Ref ref) => ownLimit;
int readCounter() => counter(null);

int nobodyAtAll() => 0;
''');
      write('lib/a.g.dart', '''
part of 'a.dart';
final counterProvider = 0;
''');
      write('lib/b.dart', '''
import 'a.dart';
final rows = [const Row()];
int use() => clamp(1) + twice() + thrice() + showSheet().hashCode;
int read() => counterProvider + readCounter();
''');
      write('test/a_test.dart', '''
import 'package:x/a.dart';
void main() => [readByTest, annotated, use()];
''');
      found = scanPublicSurface(root.path);
    });

    tearDownAll(() => root.deleteSync(recursive: true));

    SurfaceKind? kindOf(String name) =>
        found.where((f) => f.name == name).firstOrNull?.kind;

    test('a declaration only its own file uses is found', () {
      expect(kindOf('ownLimit'), SurfaceKind.ownFile);
      expect(
        kindOf('Sheet'),
        SurfaceKind.ownFile,
        reason: 'a widget behind its show function is the shape #2384 names',
      );
    });

    test('one its file and a test use is found, until annotated', () {
      expect(kindOf('readByTest'), SurfaceKind.testsOnly);
      expect(kindOf('annotated'), isNull);
    });

    test('what is surface or dead is not listed', () {
      expect(
        kindOf('Cell'),
        isNull,
        reason: 'named in the public face of Row, which is used elsewhere',
      );
      expect(
        kindOf('counter'),
        isNull,
        reason: 'its generated part names it: the provider is built from it',
      );
      expect(
        kindOf('nobodyAtAll'),
        isNull,
        reason: 'unreferenced code is the dead-code gate',
      );
    });

    test('it reports exactly those', () {
      expect(found.map((f) => f.name).toSet(), {
        'ownLimit',
        'Sheet',
        'readByTest',
      });
    });
  });
}
