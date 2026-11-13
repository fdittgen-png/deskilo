// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3811 — a refusal carries a code. Tests name the code they expect, so a
// refusal that changes its meaning fails here and not in a sentence table.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// A call refused with [code] (DKI06 "already matched", DKI04 "is matched"…).
Matcher throwsRefusal(String code) =>
    throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code));
