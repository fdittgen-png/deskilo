// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2554): the heart of My spaces is kept on the account by the
// space's qualified reference. This device's copy shows the choice at once
// and stays when the personal home refuses the reference or cannot be
// reached; once the home kept it and the list was read again, the device
// copy goes, so the account is what every device shows.
import 'package:deskilo/core/demo/data/me_repository.dart';
import 'package:deskilo/features/me/application/account_favorite.dart';
import 'package:deskilo/features/me/domain/account_favorite.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = '00000000-0000-4000-8000-0000000000e1';
const _away = '00000000-0000-4000-8000-0000000000a2';
const _ws = '00000000-0000-4000-8000-000000000101';
const _mine = '$_home:$_ws';
const _remote = '$_away:$_ws';
const _stranger = '$_away:00000000-0000-4000-8000-000000000999';

void main() {
  late FakeMeRepository repository;
  late Map<String, bool> device;
  late int reloads;
  late Exception? reloadFailure;
  late AccountFavoriteCommand command;

  setUp(() {
    repository = FakeMeRepository()
      ..workspaceRefs = const PersonalWorkspaceRefs(
        homeInstallationId: _home,
        refs: [
          PersonalWorkspaceRef(
            networkId: _mine,
            hostedHere: true,
            freshness: RefFreshness.local,
            status: RefStatus.active,
          ),
          PersonalWorkspaceRef(
            networkId: _remote,
            hostedHere: false,
            freshness: RefFreshness.verified,
            status: RefStatus.active,
          ),
        ],
      );
    device = {};
    reloads = 0;
    reloadFailure = null;
    command = AccountFavoriteCommand(
      repository: repository,
      keepOnDevice: (key, {required on}) async => device[key] = on,
      reloadAccount: () async {
        reloads++;
        if (reloadFailure case final e?) throw e;
      },
    );
  });

  Future<bool> favoriteOf(String ref) async =>
      (await repository.myWorkspaceRefs())
          .refs
          .firstWhere((r) => r.networkId == ref)
          .isFavorite;

  test('the account keeps a remote space; the device copy goes after the read',
      () async {
    final kept = await command.set(on: true, deviceKey: 'row', mark: _remote);

    expect(kept, FavoriteKept.account);
    expect(await favoriteOf(_remote), isTrue);
    expect(reloads, 1);
    expect(device['row'], isFalse, reason: 'the account is what shows now');
  });

  test('clearing takes every side the account holds off it', () async {
    await command.set(on: true, deviceKey: 'row', mark: _mine);
    await command.set(on: true, deviceKey: 'row', mark: _remote);

    final kept = await command.set(
        on: false, deviceKey: 'row', mark: _mine, clear: [_mine, _remote]);

    expect(kept, FavoriteKept.account);
    expect(await favoriteOf(_mine), isFalse);
    expect(await favoriteOf(_remote), isFalse);
    expect(repository.favoriteWrites, 4);
  });

  test('clearing a card the account holds nothing for writes only the device',
      () async {
    final kept =
        await command.set(on: false, deviceKey: 'row', mark: _stranger);

    expect(kept, FavoriteKept.account);
    expect(repository.favoriteWrites, 0);
    expect(device['row'], isFalse);
  });

  test('a refused reference is kept on this device only, nothing on the account',
      () async {
    final kept =
        await command.set(on: true, deviceKey: 'row', mark: _stranger);

    expect(kept, FavoriteKept.deviceRefused);
    expect(repository.accountFavorites, isEmpty);
    expect(device['row'], isTrue);
    expect(reloads, 0);
  });

  test('an unreachable home keeps it on this device; a retry moves it over',
      () async {
    repository.favoriteFailure = Exception('offline');

    expect(await command.set(on: true, deviceKey: 'row', mark: _remote),
        FavoriteKept.deviceUnreachable);
    expect(device['row'], isTrue);
    expect(repository.accountFavorites, isEmpty);

    repository.favoriteFailure = null;
    expect(await command.set(on: true, deviceKey: 'row', mark: _remote),
        FavoriteKept.account);
    expect(await favoriteOf(_remote), isTrue);
    expect(device['row'], isFalse);
  });

  test('a failed read after the write keeps the device copy showing it',
      () async {
    reloadFailure = Exception('read failed');

    final kept = await command.set(on: true, deviceKey: 'row', mark: _mine);

    expect(kept, FavoriteKept.account);
    expect(await favoriteOf(_mine), isTrue);
    expect(device['row'], isTrue);
  });

  test('the SQLSTATEs of the writer map to refusals, the rest is transport',
      () {
    expect(accountFavoriteRefusalOf('22023'),
        AccountFavoriteRefusal.unknownReference);
    expect(accountFavoriteRefusalOf('42501'),
        AccountFavoriteRefusal.noRelationship);
    expect(accountFavoriteRefusalOf('PGRST202'),
        AccountFavoriteRefusal.unsupported);
    expect(accountFavoriteRefusalOf('08006'), isNull);
    expect(accountFavoriteRefusalOf(null), isNull);
  });
}
