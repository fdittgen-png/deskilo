// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3401 -- the `lib/` directories of the packages under `packages/`, so a
// lint that reads the application's `lib/` can read the code that moved out
// of it too, without a list to forget to extend.
import 'dart:io';

/// `packages/<name>/lib` for every package that has a `lib/`, sorted.
List<String> packageLibRoots() => [
  if (Directory('packages').existsSync())
    for (final d in Directory('packages').listSync().whereType<Directory>())
      if (Directory('${d.path}/lib').existsSync())
        '${d.path.replaceAll(r'\', '/')}/lib',
]..sort();
