// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- prints `public.postal_region_rules()` generated from the installed
// postal layouts: per country, whether its address form asks for the region
// and whether its invoices require it.
//
//   dart run tool/build_postal_region_rules_sql.dart
//
// Paste the output into a new migration whenever a layout's region facts
// change; postal_region_rules_sql_test fails until the latest definition
// matches.
import 'dart:io';

import 'package:deskilo/core/jurisdiction/installed_postal_layouts.dart';

void main() => stdout.writeln(postalRegionRulesSql());
