// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — the library's line for stored pictures over the weight, its action,
// the picker bringing a picture to print size when it is added, and a failed
// write that leaves the stored picture as it was.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/images/report_picture_bytes.dart';
import 'package:deskilo/core/images/report_picture_sizes.dart';
import 'package:deskilo/features/money/presentation/widgets/report_image_picker.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// A noisy picture of [w] x [h] as a JPEG: heavy, and no encoder shrinks it.
Uint8List _heavyJpeg(int w, int h) {
  final p = img.Image(width: w, height: h, numChannels: 4);
  final rgba = p.data!.buffer.asUint8List();
  final random = math.Random(3984);
  for (var i = 0; i < rgba.length; i++) {
    rgba[i] = i % 4 == 3 ? 255 : random.nextInt(256);
  }
  return img.encodeJpg(p, quality: 92);
}

class _Library extends FakeMoneyRepository {
  _Library({this.refuseUpload = false});

  final bool refuseUpload;
  String? lastType;

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    if (refuseUpload) throw StateError('storage refused the write');
    lastType = contentType;
    await super.uploadReportImage(
      workspaceId,
      name: name,
      bytes: bytes,
      contentType: contentType,
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Library repository, {
  XFile? pick,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: repository,
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        if (pick != null)
          filePickerProvider.overrideWithValue((_) async => pick),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showReportImagePicker(context, ref),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.text('Open'));
  await _until(tester, () => true);
}

/// Pumps, giving real time to the codec, until [done] holds.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i > 2 && done()) return;
  }
  fail('the condition never held');
}

void main() {
  const line = ValueKey('report-images-print-size');

  testWidgets('a stored picture over the weight shows the line, and the '
      'action replaces it under the same name', (tester) async {
    final heavy = _heavyJpeg(1600, 1200);
    expect(heavy.lengthInBytes, greaterThan(reportPictureMaxBytes));
    final repository = _Library()..reportImages['stamp'] = heavy;
    await _open(tester, repository);
    await _until(tester, () => find.byKey(line).evaluate().isNotEmpty);
    expect(find.text('1 stored picture is larger than it prints'), findsOne);

    await tester.tap(
      find.byKey(const ValueKey('report-images-bring-to-print')),
    );
    await _until(
      tester,
      () => repository.reportImages['stamp']!.length <= reportPictureMaxBytes,
    );
    expect(repository.lastType, 'image/jpeg');
    expect(repository.reportImages.keys, ['stamp'], reason: 'the name stays');
    await _until(tester, () => find.byKey(line).evaluate().isEmpty);
  });

  testWidgets('a picture within the weight shows no line', (tester) async {
    final repository = _Library()
      ..reportImages['small'] = img.encodeJpg(
        img.Image(width: 8, height: 8),
        quality: 80,
      );
    await _open(tester, repository);
    await _until(tester, () => find.byKey(line).evaluate().isEmpty);
    expect(find.byKey(line), findsNothing);
  });

  testWidgets('a failed write leaves the stored picture as it was and names '
      'it', (tester) async {
    final heavy = _heavyJpeg(1600, 1200);
    final repository = _Library(refuseUpload: true)
      ..reportImages['stamp'] = heavy;
    await _open(tester, repository);
    await _until(tester, () => find.byKey(line).evaluate().isNotEmpty);
    await tester.tap(
      find.byKey(const ValueKey('report-images-bring-to-print')),
    );
    await _until(
      tester,
      () => find
          .byKey(const ValueKey('report-images-bring-failed'))
          .evaluate()
          .isNotEmpty,
    );
    expect(repository.reportImages['stamp'], heavy);
    expect(find.textContaining('stamp'), findsWidgets);
  });

  testWidgets('a large picture added in the dialog is stored at print size, '
      'its name unchanged and its type read from its bytes', (tester) async {
    final big = _heavyJpeg(2600, 1800);
    final repository = _Library();
    await _open(
      tester,
      repository,
      pick: XFile.fromData(big, name: 'Header.PNG', path: 'Header.PNG'),
    );
    await tester.tap(find.byKey(const ValueKey('report-image-upload')));
    await _until(tester, () => repository.reportImages.isNotEmpty);
    final stored = Uint8List.fromList(repository.reportImages.values.single);
    expect(stored.lengthInBytes, lessThanOrEqualTo(reportPictureMaxBytes));
    expect(reportPictureTypeOf(stored), 'image/jpeg');
    expect(repository.lastType, 'image/jpeg', reason: 'not the .png ending');
    final out = img.decodeImage(stored)!;
    expect(math.max(out.width, out.height), lessThanOrEqualTo(2200));
  });
}
