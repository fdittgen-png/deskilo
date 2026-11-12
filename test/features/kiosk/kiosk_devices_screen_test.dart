// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — the kiosk devices screen: enrolling this device keeps the
// credential on this device only and the list names it; a refused
// enrolment keeps nothing and says so; revoking the device in hand forgets
// it here too; a list that could not be read says so and Try again reads
// it; on "any device" the recommendation stands, and switching to
// "enrolled kiosks only" with no kiosk enrolled asks first.
import 'package:deskilo/core/backend/kiosk_credential_store.dart';
import 'package:deskilo/core/demo/data/demo_kiosk_devices.dart';
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/kiosk/domain/kiosk_device.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_devices_screen.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _ws = 'ws-1';
const _where = 'security.badge_signin_where';

final _whereDefinition = SettingDefinition(
  key: _where,
  type: SettingType.choice,
  defaultValue: 'enrolled_kiosks',
  group: 'security',
  scopes: {SettingScope.workspace},
  editPermission: 'workspaceSettings',
  choices: const ['enrolled_kiosks', 'any_device'],
);

/// The Demo's devices, with a way to refuse an enrolment or a first read.
class _Devices extends DemoKioskDevices {
  _Devices({this.refuseEnrol = false, this.failReads = 0, bool seeded = true})
    : super(workspaceId: _ws, today: kTestNow) {
    if (!seeded) revokeAllNow = true;
  }

  final bool refuseEnrol;
  int failReads;
  bool revokeAllNow = false;

  @override
  Future<List<KioskDevice>> list(String workspaceId) async {
    if (revokeAllNow) {
      revokeAllNow = false;
      for (final d in held) {
        await revoke(d.id);
      }
    }
    if (failReads > 0) {
      failReads--;
      throw const PostgrestException(message: 'down');
    }
    return super.list(workspaceId);
  }

  @override
  Future<KioskEnrolment> enrol(String workspaceId, String name) async {
    if (refuseEnrol) throw const PostgrestException(message: 'not allowed');
    return super.enrol(workspaceId, name);
  }
}

Future<({InMemoryKioskCredentialStore store, FakeSettingsRepository settings})>
_pump(WidgetTester tester, _Devices devices, {String? where}) async {
  final store = InMemoryKioskCredentialStore();
  final settings = FakeSettingsRepository([_whereDefinition]);
  if (where != null) {
    settings.versions['$_ws|$_where'] = [
      SettingVersion(
        scope: SettingScope.workspace,
        workspaceId: _ws,
        key: _where,
        value: where,
        validFrom: kTestNow.toIso8601String(),
      ),
    ];
  }
  await pumpApp(
    tester,
    const KioskDevicesScreen(),
    size: const Size(800, 1600),
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
        kioskDevices: devices,
        kioskCredentials: store,
      ),
      settingsRepositoryProvider.overrideWithValue(settings),
      settingsBundleLoaderProvider.overrideWithValue(
        () async => [_whereDefinition],
      ),
    ],
  );
  await tester.pumpAndSettle();
  return (store: store, settings: settings);
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('enrolling this device keeps its credential here and the list '
      'names it as this device', (tester) async {
    final pumped = await _pump(tester, _Devices());
    expect(
      _key('kiosk-device-${DemoKioskDevices.frontDeskId}'),
      findsOneWidget,
    );
    await tester.enterText(_key('kiosk-enrol-name'), 'Hall kiosk');
    await tester.pumpAndSettle();
    await tester.tap(_key('kiosk-enrol'));
    await tester.pumpAndSettle();
    final held = await pumped.store.read();
    expect(held?.workspaceId, _ws);
    expect(held?.name, 'Hall kiosk');
    expect(_key('kiosk-this-device-enrolled'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('kiosk-device-${held!.deviceId}'),
        matching: find.textContaining('This device'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refused enrolment keeps nothing on the device and says so', (
    tester,
  ) async {
    final pumped = await _pump(tester, _Devices(refuseEnrol: true));
    await tester.enterText(_key('kiosk-enrol-name'), 'Hall kiosk');
    await tester.pumpAndSettle();
    await tester.tap(_key('kiosk-enrol'));
    await tester.pumpAndSettle();
    expect(await pumped.store.read(), isNull);
    expect(
      find.text('This device could not be enrolled. Try again.'),
      findsOneWidget,
    );
    expect(
      _key('kiosk-enrol'),
      findsOneWidget,
      reason: 'the form stays, to try again',
    );
  });

  testWidgets('revoking the device in hand forgets it here too', (
    tester,
  ) async {
    final pumped = await _pump(tester, _Devices());
    await tester.enterText(_key('kiosk-enrol-name'), 'Hall kiosk');
    await tester.pumpAndSettle();
    await tester.tap(_key('kiosk-enrol'));
    await tester.pumpAndSettle();
    final id = (await pumped.store.read())!.deviceId;
    await tester.tap(_key('kiosk-device-revoke-$id'));
    await tester.pumpAndSettle();
    await tester.tap(_key('kiosk-revoke-confirm'));
    await tester.pumpAndSettle();
    expect(await pumped.store.read(), isNull);
    expect(
      _key('kiosk-device-revoke-$id'),
      findsNothing,
      reason: 'revoked: nothing to revoke',
    );
    expect(
      _key('kiosk-enrol'),
      findsOneWidget,
      reason: 'it may be enrolled again',
    );
  });

  testWidgets('a list that could not be read says so; Try again reads it', (
    tester,
  ) async {
    await _pump(tester, _Devices(failReads: 1));
    expect(_key('kiosk-devices-failed'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(_key('kiosk-devices-failed'), findsNothing);
    expect(
      _key('kiosk-device-${DemoKioskDevices.frontDeskId}'),
      findsOneWidget,
    );
  });

  testWidgets('on any device the recommendation stands; switching with no '
      'kiosk enrolled asks first, and Cancel changes nothing', (tester) async {
    final pumped = await _pump(
      tester,
      _Devices(seeded: false),
      where: 'any_device',
    );
    expect(_key('kiosk-where-recommend'), findsOneWidget);
    await tester.tap(find.text('Enrolled kiosks only'));
    await tester.pumpAndSettle();
    expect(find.text('No kiosk is enrolled'), findsOneWidget);
    await tester.tap(_key('kiosk-where-cancel'));
    await tester.pumpAndSettle();
    expect(pumped.settings.writes, isEmpty);
    expect(_key('kiosk-where-recommend'), findsOneWidget);
    await tester.tap(find.text('Enrolled kiosks only'));
    await tester.pumpAndSettle();
    await tester.tap(_key('kiosk-where-confirm'));
    await tester.pumpAndSettle();
    expect(pumped.settings.writes.single.value, 'enrolled_kiosks');
    expect(_key('kiosk-where-recommend'), findsNothing);
  });
}
