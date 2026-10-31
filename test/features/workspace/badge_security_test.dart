// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Badge administrators see a localized PIN refresh notice in the real manager;
// a plain member or disabled feature performs no review lookup, and a failed
// lookup cannot claim the PIN is current. Security alerts keep their meaning.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/features/workspace/presentation/widgets/badge_manager_dialog.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class _BadgeReviewRepository extends FakeWorkspaceRepository {
  _BadgeReviewRepository({bool enabled = true})
    : super.withWorkspace(
        featureFlags: {
          'kioskMode': true,
          'nfcBadges': true,
          'badgeSignIn': enabled,
        },
      );
  final Set<String> legacyBadgePinMembers = {};
  final List<(String, String)> badgePinReviewReads = [];
  @override
  Future<bool> badgePinNeedsReview(String workspaceId, String memberId) async {
    badgePinReviewReads.add((workspaceId, memberId));
    return legacyBadgePinMembers.contains(memberId);
  }
}

class _ReviewUnavailable extends _BadgeReviewRepository {
  @override
  Future<bool> badgePinNeedsReview(String workspaceId, String memberId) async =>
      throw StateError('review unavailable');
}

_BadgeReviewRepository _workspace({bool enabled = true}) =>
    _BadgeReviewRepository(enabled: enabled);

Future<void> _open(
  WidgetTester tester,
  FakeWorkspaceRepository repository, {
  String language = 'en',
}) async {
  final l10n = lookupAppLocalizations(Locale(language));
  await pumpApp(
    tester,
    BadgeManagerDialog(
      workspaceId: 'ws-1',
      memberId: 'member-2',
      name: 'Alex',
      l10n: l10n,
      issue: () => repository.issueMemberBadge('ws-1', 'member-2'),
      registerNfc: (uid) =>
          repository.registerNfcBadge('ws-1', 'member-2', uid: uid),
      revoke: repository.revokeMemberBadge,
      delete: repository.deleteRevokedBadge,
    ),
    overrides: standardTestOverrides(workspace: repository),
    locale: Locale(language),
    size: const Size(800, 1200),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$language: the badge manager explains the legacy PIN', (
      tester,
    ) async {
      final repository = _workspace()..legacyBadgePinMembers.add('member-2');
      await _open(tester, repository, language: language);
      expect(
        find.text(
          lookupAppLocalizations(Locale(language)).badgePinReviewNotice,
        ),
        findsOneWidget,
      );
      expect(repository.badgePinReviewReads, [('ws-1', 'member-2')]);
      expect(tester.takeException(), isNull);
    });
    test(
      '$language: the owner alert names the ceiling and belongs to members',
      () {
        final l10n = lookupAppLocalizations(Locale(language));
        final event = WorkspaceEvent(
          id: 'alert',
          workspaceId: 'ws-1',
          type: EventType.badgeSecurityAlert,
          action: EventAction.created,
          actorMemberId: 'owner',
          subjectMemberId: 'owner',
          payload: const {'failures': 50, 'window_minutes': 15},
          status: EventStatus.applied,
          createdAt: DateTime.utc(2026, 10, 31),
        );
        expect(
          eventTypeLabel(l10n, event.type),
          l10n.eventTypeBadgeSecurityAlert,
        );
        expect(
          eventLine(l10n, event, const {}, const {}, MoneyFormat('EUR')),
          l10n.eventBadgeSecurityAlert(50, 15),
        );
        expect(categoryOfEvent(event), NotificationCategory.members);
      },
    );
  }
  testWidgets('a plain member never requests another account PIN review', (
    tester,
  ) async {
    final repository = _workspace()..legacyBadgePinMembers.add('member-2');
    repository.myMember = repository.myMember.copyWith(
      isOwner: false,
      isAdmin: false,
    );
    await _open(tester, repository);
    expect(find.byKey(const ValueKey('badge-pin-review-notice')), findsNothing);
    expect(repository.badgePinReviewReads, isEmpty);
  });
  testWidgets('badge sign-in off hides the notice without a lookup', (
    tester,
  ) async {
    final repository = _workspace(enabled: false)
      ..legacyBadgePinMembers.add('member-2');
    await _open(tester, repository);
    expect(find.byKey(const ValueKey('badge-pin-review-notice')), findsNothing);
    expect(repository.badgePinReviewReads, isEmpty);
  });
  testWidgets('a current PIN needs no notice', (tester) async {
    final repository = _workspace();
    await _open(tester, repository);
    expect(find.byKey(const ValueKey('badge-pin-review-notice')), findsNothing);
    expect(repository.badgePinReviewReads, [('ws-1', 'member-2')]);
  });
  testWidgets('a failed review stays unavailable rather than current', (
    tester,
  ) async {
    await _open(tester, _ReviewUnavailable());
    expect(
      find.byKey(const ValueKey('badge-pin-review-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('badge-pin-review-notice')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
