// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Run step pages for booking limits and notifications. Limits: the
// availability screen's rows arrive with the stored rules, a change shows
// in the member's sentences before saving, Save stores every changed limit
// and only those, and a shortest booking longer than the longest is
// refused before anything is sent. Notifications: the notices follow the
// switched-on features, the push line says whether phone notifications are
// on, the reminder's lead time arrives from the settings registry, a pick
// redraws the member's reminder before saving and Save stores a new value;
// a registry without the setting shows the lead time it falls back to and
// offers nothing to save. Every page is one column on a phone.
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/application/save_booking_limits.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);
const _leadKey = 'booking.check_in_reminder_lead_minutes';

final _lead = SettingDefinition(
  key: _leadKey,
  type: SettingType.integer,
  defaultValue: 15,
  min: 1,
  max: 120,
  unit: 'minutes',
  group: 'booking',
  scopes: {SettingScope.platform, SettingScope.workspace},
  editPermission: 'workspaceSettings',
);

Future<void> _pump(
  WidgetTester tester,
  String stepId,
  FakeWorkspaceRepository repo, {
  FakeSettingsRepository? settings,
}) async {
  final store = settings ?? FakeSettingsRepository(const []);
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId),
    size: _phone,
    overrides: [
      ...standardTestOverrides(workspace: repo),
      settingsRepositoryProvider.overrideWithValue(store),
      settingsBundleLoaderProvider.overrideWithValue(
        () async => [...store.definitions.values],
      ),
    ],
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void _oneColumn(WidgetTester tester) {
  expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
  expect(tester.takeException(), isNull);
}

/// Opens the dropdown of the row [suffix] and picks [option].
Future<void> _pick(WidgetTester tester, String suffix, String option) async {
  final dropdown = find.byKey(ValueKey('$suffix-dropdown'));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  group('limits', () {
    FakeWorkspaceRepository repo() =>
        FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'bookingPolicies': true},
          )
          ..bookingPolicies['ws-1'] = const BookingPolicies(
            simultaneousReservations: 2,
            advanceHorizonDays: 30,
            minDurationMinutes: 60,
            maxDurationMinutes: 480,
          );

    testWidgets('prefilled; a change shows before saving and Save stores '
        'the changed limits', (tester) async {
      final r = repo();
      await _pump(tester, 'limits', r);
      expect(
        _text(tester, 'setup-limits-preview-ahead'),
        'You can book up to 30 days ahead.',
      );
      expect(
        _text(tester, 'setup-limits-preview-length'),
        'A booking lasts at least 1 hour and at most 8 hours.',
      );
      expect(
        _text(tester, 'setup-limits-preview-at-once'),
        'You can hold up to 2 places at a time.',
      );

      await tester.tap(
        find.byKey(const ValueKey('setup-limits-simultaneous-plus')),
      );
      await tester.pump();
      await _pick(tester, 'setup-limits-horizon', '60 days');
      expect(
        _text(tester, 'setup-limits-preview-at-once'),
        'You can hold up to 3 places at a time.',
      );
      expect(
        _text(tester, 'setup-limits-preview-ahead'),
        'You can book up to 60 days ahead.',
      );
      expect(r.bookingPolicies['ws-1']!.simultaneousReservations, 2);

      final save = find.byKey(const ValueKey('setup-limits-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final stored = r.bookingPolicies['ws-1']!;
      expect(stored.simultaneousReservations, 3);
      expect(stored.advanceHorizonDays, 60);
      expect(stored.minDurationMinutes, 60);
      expect(stored.maxDurationMinutes, 480);
      _oneColumn(tester);
    });

    testWidgets('a shortest booking longer than the longest is said and '
        'cannot be saved', (tester) async {
      final r = repo();
      await _pump(tester, 'limits', r);
      await _pick(tester, 'setup-limits-min-duration', '10 hours');
      expect(
        find.byKey(const ValueKey('setup-limits-conflict')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('setup-limits-save')),
            )
            .onPressed,
        isNull,
      );
      expect(r.bookingPolicies['ws-1']!.minDurationMinutes, 60);
    });

    test('the command sends only what changed and refuses incoherent '
        'durations', () async {
      final r = repo();
      const from = BookingPolicies(maxDurationMinutes: 480);
      await SaveBookingLimits(r)
          .save('ws-1', from: from, to: from.copyWith(minDurationMinutes: 45));
      final stored = r.bookingPolicies['ws-1']!;
      expect(stored.minDurationMinutes, 45);
      expect(
        stored.simultaneousReservations,
        2,
        reason: 'an unchanged limit is not written over',
      );
      expect(stored.advanceHorizonDays, 30);

      await expectLater(
        SaveBookingLimits(
          r,
        ).save('ws-1', from: from, to: from.copyWith(minDurationMinutes: 600)),
        throwsArgumentError,
      );
      expect(r.bookingPolicies['ws-1']!.minDurationMinutes, 45);
    });
  });

  group('notifications', () {
    testWidgets('the notices follow the features; the stored lead time '
        'arrives, a pick redraws the reminder and Save stores it', (
      tester,
    ) async {
      final settings = FakeSettingsRepository([_lead]);
      await settings.setValue(workspaceId: 'ws-1', key: _leadKey, value: 30);
      await _pump(
        tester,
        'notifications',
        FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {
            'pushNotifications': true,
            'memberNotifications': true,
            'messageMentions': false,
            'dunning': false,
          },
        ),
        settings: settings,
      );
      for (final event in [
        'pending_request',
        'reservation_cancelled',
        'check_in',
        'member_note',
      ]) {
        expect(
          find.byKey(ValueKey('setup-notifications-line-$event')),
          findsOneWidget,
          reason: event,
        );
      }
      expect(
        find.byKey(const ValueKey('setup-notifications-line-member_mention')),
        findsNothing,
      );
      expect(
        find.text('Whoever decides it: in the app and as a phone notification'),
        findsOneWidget,
      );
      expect(
        _text(tester, 'setup-notifications-push'),
        startsWith('Phone notifications are on.'),
      );
      expect(
        _text(tester, 'setup-notifications-preview-when'),
        "30 minutes before the booking starts, the member's phone shows:",
      );
      expect(
        _text(tester, 'setup-notifications-preview-body'),
        'Desk 4 starts at 09:00',
      );

      await _pick(tester, 'setup-notifications-lead', '1 hour');
      expect(
        _text(tester, 'setup-notifications-preview-when'),
        startsWith('1 hour before'),
      );
      expect(settings.writes, hasLength(1));

      final save = find.byKey(const ValueKey('setup-notifications-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(settings.writes.last, (
        workspaceId: 'ws-1',
        key: _leadKey,
        value: 60,
      ));
      _oneColumn(tester);
    });

    testWidgets('push off and no such setting: the page says so and offers '
        'nothing to save', (tester) async {
      await _pump(
        tester,
        'notifications',
        FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'pushNotifications': false},
        ),
      );
      expect(
        find.text('Members: in the app'),
        findsWidgets,
        reason: 'no phone notification without push',
      );
      expect(
        _text(tester, 'setup-notifications-push'),
        startsWith('Phone notifications are off'),
      );
      expect(
        _text(tester, 'setup-notifications-lead-fixed'),
        'The check-in reminder appears 15 minutes before a booking starts.',
      );
      expect(
        find.byKey(const ValueKey('setup-notifications-save')),
        findsNothing,
      );
      _oneColumn(tester);
    });
  });
}
