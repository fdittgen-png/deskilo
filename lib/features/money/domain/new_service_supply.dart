// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3864 — where a new catalogue service starts for VAT, from the business's
// own switches. A business that books places sells services connected with
// its premises (VAT Directive art. 47); one that books none sells general
// services (art. 44). This is a default the seller confirms in the service
// form; an existing service keeps the class it was saved with.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

/// The class a new service starts from: at the premises in a business that
/// [booksPlaces], a general service otherwise.
SupplyClass newServiceSupplyClass({required bool booksPlaces}) =>
    booksPlaces ? SupplyClass.property : SupplyClass.general;

/// Whether the service form asks for the class: only a VAT-registered
/// seller ([vatRegistered]) has a place of supply to choose, when it
/// [classifies] its supplies or when it books no places (its default then is
/// not the premises, so it is never silent).
bool asksSupplyClass({
  required bool vatRegistered,
  required bool classifies,
  required bool booksPlaces,
}) => vatRegistered && (classifies || !booksPlaces);
