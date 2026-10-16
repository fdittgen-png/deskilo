// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2591 C2 — the report template and image library are a port of their own:
// the template provider is built with a fake of that port alone, and the
// composed repository hands every call to the port it was given.
import 'dart:typed_data';

import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_template_repository.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Templates implements ReportTemplateRepository {
  final calls = <String>[];

  @override
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId) async {
    calls.add('template:$workspaceId');
    return InvoicePdfTemplate.empty;
  }

  @override
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async => calls.add('set:$workspaceId');

  @override
  Future<List<String>> listReportImages(String workspaceId) async {
    calls.add('list:$workspaceId');
    return const ['logo.png'];
  }

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async => calls.add('upload:$workspaceId:$name');

  @override
  Future<Uint8List?> fetchReportImage(String workspaceId, String name) async {
    calls.add('image:$workspaceId:$name');
    return null;
  }
}

void main() {
  test(
    'the composed repository hands each call to the template port',
    () async {
      final templates = _Templates();
      final repo = SupabaseMoneyRepository(
        SupabaseClient('http://localhost', 'anon'),
        templates: templates,
      );

      await repo.fetchInvoicePdfTemplate('w1');
      await repo.setInvoicePdfTemplate('w1', InvoicePdfTemplate.empty);
      expect(await repo.listReportImages('w1'), ['logo.png']);
      await repo.uploadReportImage(
        'w1',
        name: 'logo.png',
        bytes: const [1],
        contentType: 'image/png',
      );
      expect(await repo.fetchReportImage('w1', 'logo.png'), isNull);

      expect(templates.calls, [
        'template:w1',
        'set:w1',
        'list:w1',
        'upload:w1:logo.png',
        'image:w1:logo.png',
      ]);
    },
  );

  test('the template port is overridable on its own', () {
    final templates = _Templates();
    final container = ProviderContainer(
      overrides: [
        reportTemplateRepositoryProvider.overrideWithValue(templates),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(reportTemplateRepositoryProvider), same(templates));
  });
}
