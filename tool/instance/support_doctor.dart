// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

import 'package:deskilo/core/diagnostics/doctor_support.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';

/// The existing read-only doctor supplies findings. The support boundary never
/// emits exception text, stacks, command arguments or environment values.
Future<int> runSupportDoctor(
  Future<List<DoctorFinding>> Function() examine, {
  IOSink? out,
  IOSink? err,
  DateTime Function()? clock,
}) async {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final now = (clock ?? DateTime.now)().toUtc();
  List<DoctorFinding> findings;
  try {
    findings = await examine();
  } catch (e) {
    // trace-exempt: operator export deliberately suppresses sensitive provider
    // errors and stacks; a stable code plus unavailable checks is the result.
    errors.writeln('support_unavailable');
    output.writeln(doctorSupportBundle(const [], now).preview);
    return 1;
  }
  output.writeln(doctorSupportBundle(findings, now).preview);
  return hasProblem(findings) || findings.isEmpty ? 1 : 0;
}
