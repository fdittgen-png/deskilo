// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_stores.dart';

part 'resume_place_store.g.dart';

/// Where an account was when the app last ran, as the JSON `ResumePlaces`
/// writes — one entry per account, so the next person to sign in on a
/// shared device never reads the previous one's. Widget tests and the Demo
/// session swap in the in-memory store.
abstract class ResumePlaceStore {
  Future<String?> read(String account);
  Future<void> write(String account, String? record);
}

class _PrefsResumePlaceStore implements ResumePlaceStore {
  const _PrefsResumePlaceStore();

  PrefsStringStore _of(String account) =>
      PrefsStringStore('resume_places.$account');

  @override
  Future<String?> read(String account) => _of(account).read();

  @override
  Future<void> write(String account, String? record) =>
      _of(account).write(record);
}

/// Test double and Demo copy. [writes] counts every write.
class InMemoryResumePlaceStore implements ResumePlaceStore {
  InMemoryResumePlaceStore([Map<String, String>? values])
    : values = values ?? {};

  final Map<String, String> values;
  int writes = 0;

  @override
  Future<String?> read(String account) async => values[account];

  @override
  Future<void> write(String account, String? record) async {
    writes++;
    if (record == null) {
      values.remove(account);
    } else {
      values[account] = record;
    }
  }
}

@Riverpod(keepAlive: true)
ResumePlaceStore resumePlaceStore(Ref ref) => const _PrefsResumePlaceStore();
