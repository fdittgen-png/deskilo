// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- the web addresses outside this app that more than one file links:
// spelled once, here. `external_hosts_test` fails a host that two hand-written
// files of lib/ quote (the generated translations and the Demo's invented
// addresses aside), so a second caller reads the constant.
abstract final class ExternalHosts {
  /// The project's published site: the guide, the privacy page, the API
  /// reference, and the web app's own sign-in links.
  static const projectSite = 'https://fdittgen-png.github.io/deskilo/';

  /// The hosted database service a new instance is created on.
  static const supabase = 'https://supabase.com';
}
