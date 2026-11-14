// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 (b) — the VAT number check of the reference business answers by the
// Demo's one rule (valid by its check digits, invalid by others, an outage
// when the service does not answer), and the
// analysis export answers the real snapshot read from the Demo's own figures
// so the file can be written; the sample-data card holds the Demo's one batch
// and loads no more.
import 'package:deskilo/features/money/domain/vies_check.dart';
import 'package:deskilo/features/money/providers/vies_providers.dart';
import 'package:deskilo/features/workspace/application/bi_snapshot_export.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/providers/sample_data_providers.dart';
import 'package:deskilo/features/workspace/providers/workbook_export_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bi_report_fixture.dart';
import '../../helpers/demo_outbox_journeys.dart';

void main() {
  test('a number is valid by its check digits, invalid by others, and the '
      'service that does not answer is an outage', () async {
    await withDemoSession((f, o, c) async {
      final vies = c.read(viesRepositoryProvider);
      final valid = await vies.checkVies('ws-1', 'member-1');
      expect(valid.status, ViesStatus.valid);
      expect(valid.vatId, startsWith('FR'));
      expect(valid.consultation, isNotEmpty);
      expect(valid.checkedAt, f.seededAt);
      final invalid = await vies.checkVies('ws-1', 'member-2');
      expect(invalid.status, ViesStatus.invalid);
      final outage = await vies.checkVies('ws-1', 'member-3');
      expect(outage.status, ViesStatus.unavailable);
      expect(outage.detail, isNotEmpty);
      // What the member page reads is what was recorded.
      expect((await vies.fetchViesCheck('member-1')).status, ViesStatus.valid);
      expect(
        (await vies.fetchViesCheck('member-2')).status,
        ViesStatus.invalid,
      );
      // A member with no number is never checked into validity.
      final none = await vies.checkVies('ws-1', 'member-5');
      expect(none.status, ViesStatus.none);
    });
  });

  test('the export answers from the Demo\'s own figures, in euros', () async {
    await withDemoSession((f, o, c) async {
      final april = BiPeriod(
        BiGrain.month,
        f.seededAt.year,
        f.seededAt.month - 1,
      );
      final plan = biSnapshotPlan(
        fixtureReport(),
        period: april,
        seriesLength: 3,
        window: fixtureWindow,
        limit: 60,
      );
      final export = BiSnapshotExport(
        c.read(biExportRepositoryProvider),
        isCurrent: () => true,
      );
      final snapshot = await export.take(
        plan,
        source: fixtureSource,
        format: BiExportFormat.csv,
      );
      expect(snapshot.hash, isNotEmpty);
      final money = snapshot.visuals
          .expand((v) => v.figures)
          .where((x) => x.currency.isNotEmpty);
      expect(money, isNotEmpty);
      expect({for (final m in money) m.currency}, {'EUR'});
      // A figure the Demo cannot give is a failure of that figure, said.
      expect(
        snapshot.plan.leftOut.map((l) => l.visual.id),
        contains('v6'),
        reason: 'accounts payable is not answered',
      );
      // The same ask is the same snapshot.
      final again = await export.take(
        plan,
        source: fixtureSource,
        format: BiExportFormat.csv,
      );
      expect(again.hash, snapshot.hash);
    });
  });

  test(
    'the sample-data card holds the Demo\'s one batch and loads no more',
    () async {
      await withDemoSession((f, o, c) async {
        final repo = c.read(sampleDataRepositoryProvider);
        final batch = (await repo.status('ws-1'))!;
        expect(batch.isCleared, isFalse);
        expect(batch.members, greaterThan(0));
        expect(batch.bookings, greaterThan(0));
        final filled = await repo.fill('ws-1', 'req-1');
        expect(
          filled.id,
          batch.id,
          reason: 'a fill answers the batch it holds',
        );
        expect(filled.counts, batch.counts);
        final cleared = await repo.clear('ws-1', batch.id);
        expect(
          cleared.isCleared,
          isFalse,
          reason: 'the Demo cannot be cleared',
        );
        expect((await repo.status('ws-1'))!.id, batch.id);
      });
    },
  );
}
