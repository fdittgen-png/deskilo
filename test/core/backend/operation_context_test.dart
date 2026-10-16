// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the pure context values: targets, namespaces, epochs, and the
// per-target cache view.
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/cache/target_cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/settings/settings_capture.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceContext _context({
  String installation = 'inst-a',
  String workspace = 'ws-1',
  String localUser = 'u-a',
  int personalEpoch = 1,
  int workspaceEpoch = 1,
}) {
  final target = WorkspaceTarget.local(
    installationId: installation,
    workspaceId: workspace,
  );
  return WorkspaceContext(
    identity: const CanonicalIdentity(issuer: 'https://p/auth/v1', subject: 'p-1'),
    target: target,
    workspaceLocalUserId: localUser,
    personalEpoch: personalEpoch,
    workspaceEpoch: workspaceEpoch,
    settings: SettingsCapture(
      SettingsIdentity(installation: installation, workspaceId: workspace, principal: localUser),
      SettingsSet.defaults(const []),
    ),
    timezone: 'Europe/Paris',
  );
}

void main() {
  test('equal local workspace ids on two installations are two targets', () {
    final a = _context();
    final b = _context(installation: 'inst-b');
    expect(a.target, isNot(b.target));
    expect(a.target.networkId, 'inst-a:ws-1');
    expect(a.cacheNamespace, isNot(b.cacheNamespace));
    expect(a.sameOperationAs(b), isFalse);
  });

  test('another local account on the same target has its own namespace', () {
    expect(
      _context(localUser: 'u-1').cacheNamespace,
      isNot(_context(localUser: 'u-2').cacheNamespace),
    );
  });

  test('a changed epoch is another operation context', () {
    expect(_context().sameOperationAs(_context()), isTrue);
    expect(_context().sameOperationAs(_context(workspaceEpoch: 2)), isFalse);
    expect(_context().sameOperationAs(_context(personalEpoch: 2)), isFalse);
  });

  test('an epoch moves only when the fenced thing changes', () {
    final ledger = EpochLedger();
    expect(ledger.epochOf('personal', 'p|1'), 1);
    // A token refresh keeps the fingerprint: same epoch.
    expect(ledger.epochOf('personal', 'p|1'), 1);
    // Another workspace slot never moves the personal one.
    expect(ledger.epochOf('workspace:inst-a:ws-1', 'u-a|inst-a'), 1);
    expect(ledger.epochOf('workspace:inst-b:ws-1', 'u-b|inst-b'), 1);
    expect(ledger.epochOf('personal', 'p|1'), 1);
    // Another principal, or the same URL answering as another installation.
    expect(ledger.epochOf('personal', 'p|2'), 2);
    expect(ledger.epochOf('workspace:inst-a:ws-1', 'u-a|inst-z'), 2);
  });

  test('a target cache view never answers or busts another target', () async {
    final base = InMemoryCacheStore();
    final a = TargetCacheStore(base, _context().cacheNamespace);
    final b = TargetCacheStore(base, _context(installation: 'inst-b').cacheNamespace);
    await a.put('resv:ws-1:day', ['A'], ttl: const Duration(minutes: 5));
    await b.put('resv:ws-1:day', ['B'], ttl: const Duration(minutes: 5));
    expect((await a.get('resv:ws-1:day'))!.payload, ['A']);
    expect((await b.get('resv:ws-1:day'))!.payload, ['B']);
    await a.invalidatePrefix('resv:');
    expect(await a.get('resv:ws-1:day'), isNull);
    expect((await b.get('resv:ws-1:day'))!.payload, ['B']);
  });
}
