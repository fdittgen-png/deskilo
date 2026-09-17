// SPDX-License-Identifier: 0BSD
//
// #1327 — process state is derived, never stored: Active, Partial,
// Available and Needs attention follow the audit's definitions over the
// live registry, a partial process answers both the Active and the
// Available filter, and a card's dependency warning names only the
// prerequisites another process owns that are not already on.
import 'package:deskilo/features/workspace/application/process_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessStatus _status(Map<String, dynamic> flags, String key) =>
    processStatuses(
      resolveEnabledFeatures(flags),
    ).singleWhere((s) => s.process.key == key);

void main() {
  test('defaults: a process whose every feature is on is Active', () {
    final status = _status(const {}, 'integrations');
    expect(status.state, ProcessState.active);
    expect(status.activeSubprocessCount, status.subprocesses.length);
    expect(status.outsidePrerequisites, isEmpty);
  });

  test(
    'some features on is Partial, and matches both Active and Available',
    () {
      final status = _status(const {}, 'membershipCommerce');
      expect(status.state, ProcessState.partial);
      expect(status.matches(ProcessFilter.active), isTrue);
      expect(status.matches(ProcessFilter.available), isTrue);
      expect(status.matches(ProcessFilter.needsAttention), isFalse);
    },
  );

  test('none on is Available, and warns about a prerequisite from another '
      'process', () {
    final status = _status(const {
      'moneyTab': false,
      'services': false,
      'priceNegotiations': false,
      'memberPaymentTerms': false,
    }, 'membershipCommerce');

    expect(status.state, ProcessState.available);
    expect(status.matches(ProcessFilter.active), isFalse);
    expect(
      status.outsidePrerequisites,
      [(feature: WorkspaceFeature.moneyTab, processKey: 'billingPayments')],
      reason:
          'invoicing is still stored on, so it is not named: switching '
          'the process on would not change it',
    );
  });

  test('a feature stored on behind a switched-off parent Needs attention, '
      'and names the switch it waits for', () {
    final status = _status(const {'kioskMode': false}, 'workspaceAccess');

    expect(status.state, ProcessState.needsAttention);
    expect(status.matches(ProcessFilter.needsAttention), isTrue);
    final physical = status.subprocesses.singleWhere(
      (s) => s.subprocess.key == 'physicalAccess',
    );
    expect(physical.state, ProcessState.needsAttention);
    expect(
      physical.heldBack,
      contains((
        feature: WorkspaceFeature.nfcBadges,
        waitingFor: WorkspaceFeature.kioskMode,
      )),
    );
    expect(physical.off, contains(WorkspaceFeature.kioskMode));
  });

  test('a chain two deep waits for its NEAREST switched-off link', () {
    // badgeSignIn -> nfcBadges -> kioskMode.
    final status = _status(const {
      'badgeSignIn': true,
      'nfcBadges': false,
    }, 'workspaceAccess');
    final physical = status.subprocesses.singleWhere(
      (s) => s.subprocess.key == 'physicalAccess',
    );
    expect(
      physical.heldBack,
      contains((
        feature: WorkspaceFeature.badgeSignIn,
        waitingFor: WorkspaceFeature.nfcBadges,
      )),
    );
  });

  test('counts add up: every selectable feature is on, off or held back', () {
    for (final status in processStatuses(resolveEnabledFeatures(const {}))) {
      for (final sub in status.subprocesses) {
        expect(
          sub.capabilityCount,
          sub.subprocess.capabilities.length,
          reason: sub.subprocess.key,
        );
      }
    }
  });
}
