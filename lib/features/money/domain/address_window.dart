// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2592 - the geometry and the window widgets live in
// packages/deskilo_document_pdf. The market default below is Deskilo's.
import 'package:deskilo_document_model/address_window_kind.dart';

export 'package:deskilo_document_pdf/address_window.dart';

/// The convention a country's envelope stock implies.
///
/// France (and Monaco, on La Poste's stock) uses the right-hand DL
/// aperture at 110 mm that the French invoice spec names; the DIN world
/// uses the left-hand one at 20 mm.
///
/// Both are sold in France — the pilot workspace's own envelope is a
/// left-window one — so this is only the DEFAULT, and the workspace
/// setting overrides it. Getting the side wrong posts the address
/// behind cardboard, which is why the override is not optional.
AddressWindow addressWindowForCountry(String countryCode) =>
    switch (countryCode.toUpperCase()) {
      'FR' || 'MC' => AddressWindow.right,
      _ => AddressWindow.left,
    };
