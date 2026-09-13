// SPDX-License-Identifier: 0BSD

/// What a drag or a tap on the level canvas places.
///
/// #1216 — there is no `select` and no `erase` member any more.
/// Selecting is what the canvas does when NO tool is armed (the field
/// is nullable), and deleting belongs to the selection rather than to a
/// mode nobody could see they were in.
enum EditorTool { office, desk, seat, image }
