// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';
import 'dart:convert';

import 'package:deskilo/core/diagnostics/doctor_support.dart';
import 'package:deskilo/core/diagnostics/support_evidence.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';

/// The existing read-only doctor supplies findings. The support boundary never
/// emits exception text, stacks, command arguments or environment values.
Future<int> runSupportDoctor(
  Future<List<DoctorFinding>> Function() examine, {
  IOSink? out,
  IOSink? err,
  DateTime Function()? clock,
  SupportEvidence? evidence,
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
  output.writeln(
    doctorSupportBundle(findings, now, evidence: evidence).preview,
  );
  return hasProblem(findings) || findings.isEmpty ? 1 : 0;
}

/// Optional local release evidence. Missing/invalid artifacts never turn an
/// unavailable check into a success and cannot leak their raw contents.
Future<SupportEvidence?> loadSupportEvidence() async {
  try {
    final file = File('docs/product/capabilities.release.json');
    if (!await file.exists() ||
        await file.length() > SupportEvidence.maxSourceBytes) {
      return null;
    }
    final bytes = await file
        .openRead(0, SupportEvidence.maxSourceBytes + 1)
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    if (bytes.length > SupportEvidence.maxSourceBytes) return null;
    return SupportEvidence.parse(utf8.decode(bytes));
  } catch (e) {
    // trace-exempt: local file errors/paths are never exported.
    return null;
  }
}
