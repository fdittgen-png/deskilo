// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the outputs this build can make from a recording. Stream 2
// (#1866 Word, #1876 storyboard, #1879 video) registers its generators
// here and owns this list; the workbench reads it through
// `taskOutputGeneratorsProvider`, so a test can replace it.

import '../package/task_output.dart';
import 'docx_output_generator.dart';

List<TaskOutputGenerator> taskOutputGeneratorList() => const [
  DocxOutputGenerator(),
];
