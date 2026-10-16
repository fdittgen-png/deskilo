// SPDX-License-Identifier: AGPL-3.0-or-later
/// Editing primitives for an ordered list of document elements: a
/// selection that follows the element it points at, insert / reorder /
/// delete, caret-safe insertion of a data-field token, and a linear
/// undo / redo history. Pure Dart: the host draws the elements, owns what
/// they mean and decides which tokens exist.
library;

export 'src/edit_history.dart';
export 'src/element_edit.dart';
export 'src/token_insertion.dart';
