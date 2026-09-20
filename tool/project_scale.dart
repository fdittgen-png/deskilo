// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1334 — `dart run tool/project_scale.dart`: what this repository
// currently holds. Printed, never committed; see `tool/project_scale/`
// for why.
import 'project_scale/scale.dart';

void main() {
  stdoutWrite(render(measures()));
}

// ignore: avoid_print
void stdoutWrite(String s) => print(s);
