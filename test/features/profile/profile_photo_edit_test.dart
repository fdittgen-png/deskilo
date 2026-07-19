// SPDX-License-Identifier: MIT
//
// The profile-photo editor on the settings surface (0038): choosing an
// image uploads it through the repository and marks the profile; removing
// it clears the photo again.
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';

class _InMemoryDevModeStore implements DevModeStore {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

// A 1×1 transparent PNG — enough for MemoryImage/codec to accept.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> pumpSettings(
  WidgetTester tester,
  FakeProfileRepository profile,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(profile: profile),
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
        filePickerProvider.overrideWithValue(
          (XTypeGroup group) async =>
              XFile.fromData(_png, name: 'me.png', mimeType: 'image/png'),
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a photo uploads it and marks the profile',
      (tester) async {
    final profile = FakeProfileRepository();
    await pumpSettings(tester, profile);

    // No photo yet.
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Tap to add a photo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a photo'));
    await tester.pumpAndSettle();

    // Uploaded to the fake and recorded on the profile.
    expect(profile.avatarBytes['user-1'], _png);
    expect(profile.profiles.single.hasAvatar, isTrue);
    expect(find.text('Photo updated'), findsOneWidget);
    expect(find.text('Tap to change'), findsOneWidget);
  });

  testWidgets('removing a photo clears it', (tester) async {
    final profile = FakeProfileRepository(
      profiles: [
        const Profile(
          id: 'user-1',
          displayName: 'Test User',
          avatarPath: 'user-1/avatar',
        ),
      ],
    )..avatarBytes['user-1'] = _png;
    await pumpSettings(tester, profile);

    expect(find.text('Tap to change'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(profile.avatarBytes.containsKey('user-1'), isFalse);
    expect(profile.profiles.single.hasAvatar, isFalse);
    expect(find.text('Photo removed'), findsOneWidget);
  });
}
