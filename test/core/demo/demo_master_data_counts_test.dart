// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 -- the Master data page in the Demo counts real records: through the
// Demo's own composition, every kind's read answers for the reference business
// (none fails, so no card shows the read failure), and each holds records.
import 'dart:async';

import 'package:deskilo/app/master_data/master_data_counts.dart';
import 'package:deskilo/app/master_data/master_data_kinds.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every kind of master data is read in the Demo, with real counts',
    () async {
      final container = ProviderContainer(
        overrides: demoOverrides(DemoFixture.build()),
      )..listen(currentWorkspaceProvider, (_, _) {});
      addTearDown(container.dispose);
      final id = (await container.read(currentWorkspaceProvider.future))!.id;
      final counts = <MasterDataKind, int>{};
      for (final k in MasterDataKind.values) {
        final source = masterDataSource(k, id);
        final answered = Completer<AsyncValue<List<Object?>>>();
        final sub = container.listen(source, (_, next) {
          if (!next.isLoading && !answered.isCompleted) answered.complete(next);
        }, fireImmediately: true);
        addTearDown(sub.close);
        final value = await answered.future;
        expect(value.hasError, isFalse, reason: '${k.name}: ${value.error}');
        counts[k] = value.requireValue.length;
      }
      // the reference business holds records of every kind
      expect(
        [
          for (final e in counts.entries)
            if (e.value == 0) e.key.name,
        ],
        isEmpty,
        reason: '$counts',
      );
    },
  );
}
