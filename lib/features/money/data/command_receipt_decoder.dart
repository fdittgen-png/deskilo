// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../domain/command_receipt.dart';

/// #2585 C2 — strict decoding of `financial_command_outcome_v1`. An unknown
/// state, or an applied answer without its invoice id, is a
/// [JsonShapeException]: the caller keeps the attempt as unknown instead of
/// reading an outcome the server did not give.
CommandReceipt decodeCommandReceipt(Object? answer) {
  final reader = JsonReader.of(answer, context: 'financial_command_outcome_v1');
  final state = reader.string('state');
  switch (state) {
    case 'not_observed':
      return const CommandReceipt(CommandReceiptState.notObserved);
    case 'applied':
      return CommandReceipt(
        CommandReceiptState.applied,
        invoiceId: _nonEmpty(reader, 'invoice_id'),
      );
    case 'pending':
      return CommandReceipt(
        CommandReceiptState.pending,
        eventId: _nonEmpty(reader, 'event_id'),
      );
    case 'refused':
      return CommandReceipt(
        CommandReceiptState.refused,
        eventId: _nonEmpty(reader, 'event_id'),
      );
  }
  throw JsonShapeException(
    reader.context,
    'state',
    'not_observed | applied | pending | refused',
    state,
  );
}

String _nonEmpty(JsonReader reader, String key) {
  final value = reader.string(key);
  if (value.isEmpty) {
    throw JsonShapeException(
      reader.context,
      key,
      'non-empty String',
      'empty String',
    );
  }
  return value;
}
