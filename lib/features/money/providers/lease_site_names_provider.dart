// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4498 -- the names of the sites of the business by id, for a lease form that says which site the lease is at. The composition root
// (lib/app) wires the workspace's sites behind it (the money feature reads no more of the workspace than it has to); with nothing
// wired no name is known and the form says the site's id.
import 'package:flutter_riverpod/flutter_riverpod.dart';

final leaseSiteNamesProvider = Provider<Map<String, String>>((ref) => const {});
