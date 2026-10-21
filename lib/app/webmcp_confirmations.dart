// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 PR 2 — the requests the contract runs only after the person
// confirms them (`confirmation: native`). The first call shows the person
// what the assistant asks and answers the agent `requires_confirmation`;
// the agent calls again with the same request_id and arguments and gets
// `requires_confirmation` until the person decides, then the outcome (or
// `declined`). Consent is the person's, in the app (ADR 0042): a call is
// never a permission, and nothing runs before Confirm.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'webmcp_writes.dart';

/// One request waiting for the person.
class WebMcpConfirmationRequest {
  const WebMcpConfirmationRequest({
    required this.key,
    required this.operation,
    required this.input,
  });

  final String key;
  final String operation;
  final Map<String, Object?> input;
}

class _Entry {
  _Entry(this.args);
  final String args;
  bool? accepted;
  Future<Map<String, Object?>>? outcome;
}

/// The page's confirmations, keyed by scope and request_id. Its state is
/// the request the shell should show now (null: none).
class WebMcpConfirmations extends Notifier<WebMcpConfirmationRequest?> {
  final _entries = <String, _Entry>{};

  @override
  WebMcpConfirmationRequest? build() => null;

  /// The outcome of [operation] under this request_id: null while the
  /// person has not decided (the request is shown the first time),
  /// otherwise the write's outcome; a declined request is refused.
  Future<Map<String, Object?>>? outcome({
    required String scope,
    required String operation,
    required Map<String, Object?> input,
    required Future<Map<String, Object?>> Function() write,
  }) {
    final requestId = input['request_id'];
    if (requestId is! String || requestId.isEmpty || requestId.length > 100) {
      throw const WebMcpRefused(
        'validation_error',
        'request_id is required: a new random UUID per intent.',
      );
    }
    final args = jsonEncode({
      for (final key in input.keys.toList()..sort())
        if (key != 'request_id') key: input[key],
    });
    final key = '$scope|$operation|$requestId';
    final entry = _entries[key];
    if (entry == null) {
      _entries[key] = _Entry(args);
      state = WebMcpConfirmationRequest(
        key: key,
        operation: operation,
        input: Map.unmodifiable(input),
      );
      return null;
    }
    if (entry.args != args) {
      throw const WebMcpRefused(
        'validation_error',
        'This request_id was used with other arguments: use a new one.',
      );
    }
    if (entry.accepted == false) {
      throw const WebMcpRefused(
        'denied',
        'The person declined this request.',
      );
    }
    if (entry.accepted == true) return entry.outcome ??= write();
    return null;
  }

  /// The person's answer to the request [key]. Confirming runs nothing
  /// yet: the write runs when the agent asks for the outcome, once.
  void decide(String key, {required bool accept}) {
    final entry = _entries[key];
    if (entry == null || entry.accepted != null) return;
    entry.accepted = accept;
    if (state?.key == key) state = null;
  }
}

final webMcpConfirmationsProvider =
    NotifierProvider<WebMcpConfirmations, WebMcpConfirmationRequest?>(
      WebMcpConfirmations.new,
    );
