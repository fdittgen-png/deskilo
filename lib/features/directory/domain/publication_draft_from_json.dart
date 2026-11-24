// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4409 — the keys of a `publication.page.read` answer, read once: the
// stored document and whether the page is published.

/// The stored document of a page answer `{published, document, following}`.
Map<String, Object?> pageDocumentOf(Map<String, Object?> page) =>
    Map<String, Object?>.from(page['document'] as Map);

/// Whether a page answer says the page is published.
bool pagePublishedOf(Map<String, Object?> page) => page['published'] == true;
