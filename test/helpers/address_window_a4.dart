// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The A4 address field's aperture and flow line in PostScript points, for the
// tests that pin them. Production reads the millimetres per paper
// (`AddressWindow.fieldOn`, #3981), never these.
import 'package:deskilo_document_model/address_window_kind.dart';

const double _mm = 72 / 25.4;

/// The aperture of the A4 field.
const double addressWindowWidth = addressWindowWidthMm * _mm;
const double addressWindowHeight = addressWindowHeightMm * _mm;

/// Where the A4 document's own content resumes under a window.
const double addressWindowFlowResume = addressWindowFlowResumeMm * _mm;
