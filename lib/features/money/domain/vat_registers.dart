// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which registers of issued invoices a country's law asks for in a file
// the app writes (`vat_register_es.dart`, `vat_register_es_sii.dart`,
// `vat_register_it.dart`).

/// A register the declarations screen offers beside the return.
enum VatRegisterKind {
  /// The Spanish libro registro de facturas expedidas, AEAT XLSX layout,
  /// from the 1st of January to the end of the period.
  esLibro,

  /// The same documents of the period as the SII message.
  esSii,

  /// The modelo 347 list of the period's year.
  es347,

  /// The Italian registro delle fatture emesse of the period.
  itRegistro,
}

/// The registers a space of [country] can save.
List<VatRegisterKind> vatRegistersFor(String country) =>
    switch (country.trim().toUpperCase()) {
      'ES' => const [
        VatRegisterKind.esLibro,
        VatRegisterKind.esSii,
        VatRegisterKind.es347,
      ],
      'IT' => const [VatRegisterKind.itRegistro],
      _ => const [],
    };
