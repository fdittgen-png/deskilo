// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (FIN-09) -- an e-invoicing address's scheme is picked by name, and its identifier is checked with that
// scheme's form before it is stored: for a customer (the member's address) and for the business (its legal identity).
// A stored scheme the list does not offer stays visible, and the address as stored saves unchanged.
import 'package:deskilo/core/ui/einvoice_scheme_field.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_identity_fields.dart';
import 'package:deskilo/features/workspace/application/set_member_einvoice_address.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/member_einvoice_address_tile.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _l10n = AppLocalizationsEn();

class _Addresses implements MemberEInvoiceAddresses {
  final stored = <String>[];

  @override
  Future<bool> set(
    Member member, {
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
  }) async {
    stored.add('$endpointScheme:$endpointId');
    return true;
  }
}

Member _member({String scheme = '', String id = ''}) => Member(
  id: 'm-2',
  workspaceId: 'ws-1',
  userId: 'u-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
  einvoiceEndpointScheme: scheme,
  einvoiceEndpointId: id,
);

Future<_Addresses> _openTile(WidgetTester tester, Member member) async {
  final addresses = _Addresses();
  await pumpApp(
    tester,
    Scaffold(body: MemberEInvoiceAddressTile(member: member)),
    overrides: [memberEInvoiceAddressesProvider.overrideWithValue(addresses)],
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('member-page-einvoice-address')));
  await tester.pumpAndSettle();
  return addresses;
}

Future<void> _pick(WidgetTester tester, Key field, String label) async {
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

EasScheme _scheme(String code) => easSchemeOf(code)!;

void main() {
  testWidgets('a customer\'s scheme is picked by name, and an identifier of another form is not stored', (
    tester,
  ) async {
    final addresses = await _openTile(tester, _member());
    await _pick(tester, const ValueKey('member-einvoice-scheme'), easSchemeLabel(_scheme('0009')));
    await tester.enterText(find.byKey(const ValueKey('member-einvoice-endpoint')), '7328');
    await tester.tap(find.byKey(const ValueKey('member-einvoice-save')));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.eInvoiceAddressIdentifierRefused('SIRET (FR)')), findsOneWidget);
    expect(addresses.stored, isEmpty, reason: 'the dialog stays open, nothing is sent');

    await tester.enterText(find.byKey(const ValueKey('member-einvoice-endpoint')), '73282932000074');
    await tester.tap(find.byKey(const ValueKey('member-einvoice-save')));
    await tester.pumpAndSettle();
    expect(addresses.stored, ['0009:73282932000074']);
  });

  testWidgets('an identifier without a scheme is not stored', (tester) async {
    final addresses = await _openTile(tester, _member());
    await tester.enterText(find.byKey(const ValueKey('member-einvoice-endpoint')), '73282932000074');
    await tester.tap(find.byKey(const ValueKey('member-einvoice-save')));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.eInvoiceAddressSchemeRefused), findsOneWidget);
    expect(addresses.stored, isEmpty);
  });

  testWidgets('a stored scheme the list does not offer stays visible, and the address saves as it was', (tester) async {
    final addresses = await _openTile(tester, _member(scheme: 'ZZ01', id: 'legacy-42'));
    expect(find.text('ZZ01'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('member-einvoice-save')));
    await tester.pumpAndSettle();
    expect(addresses.stored, ['ZZ01:legacy-42']);
  });

  testWidgets('the business\'s own address is checked the same way, the stored one kept', (tester) async {
    final form = EInvoiceIdentityForm()
      ..load(const InvoiceLegal(einvoiceEndpointScheme: 'ZZ01', einvoiceEndpointId: 'old'));
    addTearDown(form.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: EInvoiceIdentityFields(form: form, country: 'FR'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ZZ01'), findsWidgets);
    expect(form.addressAccepted(_l10n), isTrue, reason: 'the address as stored');

    await _pick(tester, const ValueKey('legal-identity-einvoice-scheme'), easSchemeLabel(_scheme('0225')));
    expect(form.endpointScheme.text, '0225');
    expect(form.addressAccepted(_l10n), isFalse);
    await tester.pump();
    expect(find.text(_l10n.eInvoiceAddressIdentifierRefused('Annuaire (FR)')), findsOneWidget);

    form.endpointId.text = '732829320';
    expect(form.addressAccepted(_l10n), isTrue);
    expect(form.applyTo(const InvoiceLegal()).einvoiceEndpointScheme, '0225');
  });
}
