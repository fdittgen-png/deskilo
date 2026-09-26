// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_stores.dart';

part 'entry_intent_store.g.dart';

/// #1650 — the one bounded draft of what the person came to do, on the
/// device, as the JSON `EntryIntents` writes. One string key: the draft
/// is small, versioned and expires, and there is never more than one.
/// Widget tests and the Demo session swap in the in-memory store.
abstract class EntryIntentStore {
  Future<String?> read();
  Future<void> write(String? draft);
}

class PrefsEntryIntentStore extends PrefsStringStore
    implements EntryIntentStore {
  const PrefsEntryIntentStore() : super('entry_intent_draft');
}

/// Test double and Demo copy. [writes] counts every write, so a test can
/// say "the redirect wrote nothing" and mean it.
class InMemoryEntryIntentStore implements EntryIntentStore {
  InMemoryEntryIntentStore([this.value]);

  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? draft) async {
    value = draft;
    writes++;
  }
}

@Riverpod(keepAlive: true)
EntryIntentStore entryIntentStore(Ref ref) => const PrefsEntryIntentStore();
