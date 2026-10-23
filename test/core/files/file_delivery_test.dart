// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A "download" tells the person what actually happened, per platform: a
// file they can open says where, an app-private copy says it is not in
// Downloads or Files, a browser request says it is a request (and offers
// the gesture a blocked hand-over needs), the share sheet is a hand-over,
// a closed sheet is a cancellation and a refusal is a refusal. The iPhone
// Export… choice never opens the share sheet on its own.
import 'package:deskilo/core/files/file_delivery.dart';
import 'package:deskilo/core/files/file_delivery_notice.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _Harness {
  SaveOutcome answer = const SavedFile('Download/invoice.pdf');
  FileShareOutcome shareAnswer = FileShareOutcome.sent;
  Exception? shareRefusal;
  int saves = 0;
  int shares = 0;
  final deliveries = <FileDelivery>[];

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    saves++;
    return answer;
  }

  Future<FileShareOutcome> share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    shares++;
    if (shareRefusal case final error?) throw error;
    return shareAnswer;
  }
}

/// A screen with one "Download" button that delivers and announces.
class _Screen extends ConsumerWidget {
  const _Screen(this.harness);
  final _Harness harness;

  Future<void> _deliver(BuildContext context, WidgetRef ref) async {
    final delivery = await deliverFile(
      context,
      ref,
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'invoice.pdf',
    );
    harness.deliveries.add(delivery);
    if (!context.mounted) return;
    announceFileDelivery(
      context,
      delivery,
      retry: () => _deliver(context, ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('download'),
        onPressed: () => _deliver(context, ref),
        child: const Text('Download'),
      ),
    ),
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  FileDeliveryMode mode = FileDeliveryMode.direct,
}) async {
  final h = _Harness();
  await pumpApp(
    tester,
    _Screen(h),
    overrides: [
      fileDeliveryModeProvider.overrideWithValue(mode),
      typedFileSaverProvider.overrideWithValue(h.save),
      fileSharerProvider.overrideWithValue(h.share),
    ],
  );
  await tester.pump();
  return h;
}

/// Taps [key] and lets the sheet or the snackbar come up.
Future<void> _tapAndSettle(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('direct delivery (Android, desktop, browser)', () {
    testWidgets('a file the person can open says where it is', (tester) async {
      final h = await _pump(tester);
      await _tapAndSettle(tester, 'download');
      expect(find.text('Saved to Download/invoice.pdf'), findsOneWidget);
      expect(h.deliveries.single, isA<LocalSave>());
    });

    testWidgets(
      'an app-private copy is named as such — never "Saved to" a path '
      'nobody can open',
      (tester) async {
        final h = await _pump(tester);
        h.answer = const SavedPrivately('/data/user/0/app/files/invoice.pdf');
        await _tapAndSettle(tester, 'download');
        expect(
          find.textContaining('Kept inside Deskilo: invoice.pdf'),
          findsOneWidget,
        );
        expect(find.textContaining('Saved to'), findsNothing);
        expect(
          find.textContaining('/data/user/0'),
          findsNothing,
          reason: 'an app-private path is not a place the person can go',
        );
        expect(h.saves, 1);
      },
    );

    testWidgets(
      'a browser request is a request, and "Download again" re-issues it '
      'from a user gesture',
      (tester) async {
        final h = await _pump(tester);
        h.answer = const DownloadRequested('invoice.pdf');
        await _tapAndSettle(tester, 'download');
        expect(
          find.textContaining('Download requested: invoice.pdf'),
          findsOneWidget,
        );
        expect(find.textContaining('Saved to'), findsNothing);
        expect(h.saves, 1);
        await tester.tap(find.text('Download again'));
        await tester.pump();
        expect(h.saves, 2, reason: 'the action is the retry');
      },
    );

    testWidgets('a refusal is reported as a refusal, with its reason', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.answer = const SaveFailed(SaveFailure.writeFailed);
      await _tapAndSettle(tester, 'download');
      expect(
        find.text('Could not save the file: the device refused the write.'),
        findsOneWidget,
      );
      expect(find.textContaining('Saved to'), findsNothing);
      expect(find.textContaining('Kept inside'), findsNothing);
      expect(h.shares, 0, reason: 'a local save never opens the share sheet');
    });

    testWidgets('no folder at all is named as the reason', (tester) async {
      final h = await _pump(tester);
      h.answer = const SaveFailed(SaveFailure.noStorage);
      await _tapAndSettle(tester, 'download');
      expect(
        find.text(
          'Could not save the file: no folder on this device would take it.',
        ),
        findsOneWidget,
      );
      expect(h.deliveries.single, isA<LocalSave>());
    });
  });

  group('the iPhone Export… choice', () {
    testWidgets('Keep in Deskilo writes the private copy and says so', (
      tester,
    ) async {
      final h = await _pump(tester, mode: FileDeliveryMode.exportChooser);
      h.answer = const SavedPrivately('/var/mobile/app/Documents/invoice.pdf');
      await _tapAndSettle(tester, 'download');
      expect(find.text('Export…'), findsOneWidget);
      expect(h.saves, 0, reason: 'nothing is written before the choice');
      await _tapAndSettle(tester, 'file-export-keep');
      expect(h.saves, 1);
      expect(h.shares, 0);
      expect(
        find.textContaining('Kept inside Deskilo: invoice.pdf'),
        findsOneWidget,
      );
      expect(find.textContaining('Saved to'), findsNothing);
    });

    testWidgets(
      'Share… hands the bytes to the system sheet — a hand-over, not a '
      'save',
      (tester) async {
        final h = await _pump(tester, mode: FileDeliveryMode.exportChooser);
        await _tapAndSettle(tester, 'download');
        await _tapAndSettle(tester, 'file-export-share');
        expect(h.shares, 1);
        expect(h.saves, 0);
        expect(
          find.textContaining('invoice.pdf was handed to the share sheet'),
          findsOneWidget,
        );
        expect(find.textContaining('Saved to'), findsNothing);
        expect(
          h.deliveries.single,
          isA<HandedToShareSheet>().having(
            (d) => d.confirmed,
            'confirmed',
            true,
          ),
        );
      },
    );

    testWidgets('a closed share sheet is a cancellation, not a success', (
      tester,
    ) async {
      final h = await _pump(tester, mode: FileDeliveryMode.exportChooser);
      h.shareAnswer = FileShareOutcome.dismissed;
      await _tapAndSettle(tester, 'download');
      await _tapAndSettle(tester, 'file-export-share');
      expect(find.text('Cancelled — nothing was saved.'), findsOneWidget);
      expect(h.deliveries.single, isA<DeliveryCancelled>());
    });

    testWidgets('closing the choice itself saves and shares nothing', (
      tester,
    ) async {
      final h = await _pump(tester, mode: FileDeliveryMode.exportChooser);
      await _tapAndSettle(tester, 'download');
      await _tapAndSettle(tester, 'sheet-close');
      expect(h.saves, 0);
      expect(h.shares, 0);
      expect(h.deliveries.single, isA<DeliveryCancelled>());
      expect(find.text('Cancelled — nothing was saved.'), findsOneWidget);
    });

    testWidgets('a share sheet that cannot open is a failure with its reason', (
      tester,
    ) async {
      final h = await _pump(tester, mode: FileDeliveryMode.exportChooser);
      h.shareRefusal = PlatformException(code: 'no_activity');
      await _tapAndSettle(tester, 'download');
      await _tapAndSettle(tester, 'file-export-share');
      expect(
        find.text(
          'Could not save the file: the share sheet could not be opened.',
        ),
        findsOneWidget,
      );
      expect(
        h.deliveries.single,
        isA<DeliveryFailed>().having(
          (d) => d.reason,
          'reason',
          SaveFailure.shareUnavailable,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
