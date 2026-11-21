// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the kind each of my businesses set (`business.kind`), by workspace id,
// for Me to name it. A business that chose none is absent: the registry's
// default is not a statement of the business. A server from before 0845 knows
// none, and says so by answering nothing.
abstract interface class MyBusinessKindsReader {
  /// The kind code of each business of mine that set one, by workspace id.
  Future<Map<String, String>> read();
}
