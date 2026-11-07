// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 -- moved to deskilo_vat_declaration; this path only re-exports it until
// the sweep PR (#3403) rewrites the importers and deletes it. The functions that
// read the tax reference are wrapped at their old homes.

export 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart'
    hide
        vatComponentsOf,
        vatDeclarationXml,
        vatFormBoxes,
        vatFormCatalogueOn,
        vatFormSpecFor,
        vatFormTaxesAcquisitions,
        vatQstFormBoxes;
