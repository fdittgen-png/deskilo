// SPDX-License-Identifier: AGPL-3.0-or-later

/// One CSV cell writer for every file the app exports (#2385). It lives in the
/// standards package since #3333 (the country add-ons share ONE copy); this
/// library keeps the application's callers where they were.
library;

export 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show CsvDialect, csvCell;
