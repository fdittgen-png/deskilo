// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 L5 — a previous supported client against the upgraded server, and the
// capability state against the global schema gate:
//  * the schema policy is unchanged: a server behind this app blocks, a server
//    ahead of it does not, whatever capability states the server holds;
//  * a capability the server stopped (servicing) is refused for new work with
//    the same words the app already knows, inside a supported schema;
//  * the previous client's reads keep decoding what the upgraded server sends:
//    an unknown state reads as servicing (admits nothing), an unknown phase of a
//    transmission as uncertain (never a failure that invites a resend);
//  * a version or module a client sends is only ever declared, never a selector.
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/money/application/accounting_connection_commands.dart';
import 'package:deskilo/features/money/domain/capability_state.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/renderer_declaration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('the global schema gate is unchanged by the lifecycle', () {
    test('a server behind this app blocks; one ahead of it does not', () {
      expect(
        compareSchema(requiredSchemaVersion - 1),
        SchemaCompatibility.behind,
      );
      expect(compareSchema(null), SchemaCompatibility.behind);
      expect(compareSchema(requiredSchemaVersion), SchemaCompatibility.current);
      expect(
        compareSchema(requiredSchemaVersion + 3),
        SchemaCompatibility.ahead,
      );
    });

    test(
      'the lifecycle migrations are inside the version the app requires',
      () {
        // 0692 (capability states) and 0693 (envelopes) are part of what a
        // current app expects; an older server is `behind`, never half-served.
        expect(requiredSchemaVersion, greaterThanOrEqualTo(692));
      },
    );
  });

  group('a stopped capability inside a supported schema', () {
    test('the refusal the server gives is worded, not generic', () {
      const refusal = PostgrestException(
        message: 'accounting connections are switched off in this space',
        code: '0A000',
      );
      expect(
        AccountingConnectionCommands.refusalOf(refusal),
        CapabilityRefusal.switchedOff,
      );
    });

    test('an unrelated failure keeps the generic path', () {
      expect(
        AccountingConnectionCommands.refusalOf(Exception('socket closed')),
        CapabilityRefusal.other,
      );
    });
  });

  group('the previous client reads what the upgraded server sends', () {
    test('a state this client does not know admits nothing', () {
      expect(
        CapabilityStateKind.of('quarantined'),
        CapabilityStateKind.servicing,
      );
      expect(CapabilityStateKind.of(null), CapabilityStateKind.servicing);
      expect(
        CapabilityState.fromJson(const {'state': 'quarantined'}).kind,
        CapabilityStateKind.servicing,
      );
    });

    test('a transmission phase this client does not know is uncertain', () {
      expect(
        EInvoiceSubmissionStatus.fromWire(
          phase: 'quarantined',
          status: 'failed',
        ),
        EInvoiceSubmissionStatus.uncertain,
      );
      // and a legacy row (no phase) decodes exactly as before
      expect(
        EInvoiceSubmissionStatus.fromWire(status: 'accepted'),
        EInvoiceSubmissionStatus.accepted,
      );
    });
  });

  group('a version or module a client sends is only a declaration', () {
    test(
      'the declaration carries a renderer and a version, nothing selecting',
      () {
        final json = const RendererDeclaration(
          renderer: 'facturX',
          appVersion: '1.2.3+4',
        ).toJson();
        expect(json.keys.toSet(), {'renderer', 'app_version'});
        expect(json.keys, isNot(contains('module_version')));
        expect(json.keys, isNot(contains('rule_revision')));
      },
    );
  });
}
