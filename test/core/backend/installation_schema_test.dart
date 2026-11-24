// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — the schema of the installation hosting a workspace is read
// per installation, with that installation's own client: an old business does
// not lend its verdict to another, a failed refresh keeps what THAT
// installation last answered, and silence is unknown, which never withholds.
import 'package:deskilo/core/backend/installation_schema.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A host per workspace; a host listed in [down] cannot be asked.
class _Hosts implements InstallationSchemaSource {
  final Map<String, ({String id, int? number})> hosts = {};
  final Set<String> down = {};
  final Set<String> unreachable = {};
  @override
  Future<({String installationId, int? number})> read(String w) async {
    if (unreachable.contains(w)) {
      throw const InstallationSchemaUnavailable('no route to host');
    }
    final host = hosts[w]!;
    if (down.contains(w)) {
      throw InstallationSchemaUnavailable('timeout', installationId: host.id);
    }
    return (installationId: host.id, number: host.number);
  }
}

void main() {
  late _Hosts hosts;
  late ProviderContainer c;
  setUp(() {
    hosts = _Hosts()
      ..hosts['w-old'] = (id: 'inst-old', number: appNeedsSchemaVersion - 1)
      ..hosts['w-new'] = (id: 'inst-new', number: requiredSchemaVersion);
    c = ProviderContainer(
      overrides: [installationSchemaSourceProvider.overrideWithValue(hosts)],
    );
    addTearDown(c.dispose);
  });

  Future<InstallationSchema> read(String w) =>
      c.read(workspaceSchemaProvider(w).future);

  test('one installation is behind and another works', () async {
    expect((await read('w-old')).verdict, SchemaCompatibility.behind);
    expect((await read('w-new')).verdict, SchemaCompatibility.current);
  });

  test('an older but sufficient installation stays usable', () async {
    hosts.hosts['w-mid'] = (id: 'inst-mid', number: appNeedsSchemaVersion);
    final mid = await read('w-mid');
    expect(mid.verdict, SchemaCompatibility.current);
    expect(mid.featureSchema, appNeedsSchemaVersion);
  });

  test('a host without the marker is an answer: behind, feature schema 0',
      () async {
    hosts.hosts['w-bare'] = (id: 'inst-bare', number: null);
    final bare = await read('w-bare');
    expect(bare.answered, isTrue);
    expect(bare.verdict, SchemaCompatibility.behind);
    expect(bare.featureSchema, 0);
  });

  test('a host that was never read is unknown and withholds nothing', () async {
    hosts.unreachable.add('w-new');
    final s = await read('w-new');
    expect(s.verdict, SchemaCompatibility.unknown);
    expect(s.featureSchema, isNull);
  });

  test('a failed refresh keeps what that installation last said, no more',
      () async {
    expect((await read('w-old')).verdict, SchemaCompatibility.behind);
    expect((await read('w-new')).verdict, SchemaCompatibility.current);
    hosts.down.addAll(['w-old', 'w-new']);
    c
      ..invalidate(workspaceSchemaProvider('w-old'))
      ..invalidate(workspaceSchemaProvider('w-new'));
    expect((await read('w-old')).verdict, SchemaCompatibility.behind);
    expect((await read('w-new')).verdict, SchemaCompatibility.current);
  });

  test('a newer successful answer replaces the kept one', () async {
    expect((await read('w-old')).verdict, SchemaCompatibility.behind);
    hosts.hosts['w-old'] = (id: 'inst-old', number: requiredSchemaVersion);
    c.invalidate(workspaceSchemaProvider('w-old'));
    expect((await read('w-old')).verdict, SchemaCompatibility.current);
  });

  test('a host never read does not borrow the verdict of another', () async {
    expect((await read('w-old')).verdict, SchemaCompatibility.behind);
    hosts.hosts['w-other'] = (id: 'inst-other', number: requiredSchemaVersion);
    hosts.down.add('w-other');
    expect((await read('w-other')).verdict, SchemaCompatibility.unknown);
  });
}
