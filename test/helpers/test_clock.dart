// SPDX-License-Identifier: 0BSD
//
// Moved to lib/core/demo/data by ADR 0028: the fixture's clock is the
// Demo environment's clock too — a 'today' booking must not expire out
// of the demo. This shim keeps every existing import working.
export 'package:deskilo/core/demo/data/fixture_clock.dart';
