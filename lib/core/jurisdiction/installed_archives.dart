// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the archive add-ons this build installs: a static list,
// compiled in, like the other capabilities. A country not listed asks nothing
// beyond the documents of its archive.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:deskilo_jurisdiction_ie/deskilo_jurisdiction_ie.dart';
import 'package:deskilo_jurisdiction_us/deskilo_jurisdiction_us.dart';
import 'package:meta/meta.dart';

import 'jurisdiction_resolver.dart';

/// Every installed archive add-on.
@visibleForTesting
const List<ArchiveContribution> installedArchives = [
  CaArchive(),
  ChArchive(),
  FrArchive(),
  GbArchive(),
  IeArchive(),
  UsArchive(),
];

/// What [country]'s law asks of its archive, or null when nothing.
ArchiveContribution? archiveOf(String country) =>
    resolveArchive(LegalContext(countryCode: country), installedArchives);
