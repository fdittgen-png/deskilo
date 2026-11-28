// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4510 (FIN-05) -- a line of a quote or an invoice may be picked from the service catalogue: its name fills an empty
// description, its price (VAT-inclusive) fills the price as a gross price, its VAT rate and what it supplies fill the line, and
// the line keeps the service's identity. Every field stays editable; "no service" keeps an ad-hoc line; a service retired since
// stays shown on the line that holds it; choosing goods gives the service up. The editor stays whole on a phone and on a desktop.
import 'package:deskilo/features/money/domain/invoice_goods.dart';
import 'package:deskilo/features/money/domain/invoice_services.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/standalone/standalone_line_form.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _coaching = InvoiceService(id: 'svc-coaching', name: 'Coaching', priceCents: 12000, vatRateId: 'rate-red', supply: 'general');
const _desk = InvoiceService(id: 'svc-desk', name: 'Desk day', priceCents: 1500);
const _mugs = InvoiceGoodsItem(id: 'item-mugs', name: 'Mugs', unit: 'piece');
const _rates = [
  VatRate(id: 'rate-std', label: 'Standard', percent: 20, isDefault: true),
  VatRate(id: 'rate-red', label: 'Reduced', percent: 10),
];

Future<BuildContext> _pump(WidgetTester tester, StandaloneLineForm form, {required Size size, List<InvoiceService> services = const [_coaching, _desk]}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [invoicingBusinessProvider.overrideWithValue((id: 'ws', currency: 'EUR', country: 'FR', dayOf: (d) => d))],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (c, setState) {
                context = c;
                return StandaloneLineEditor(
                  index: 0,
                  form: form,
                  rates: _rates,
                  goods: const [_mugs],
                  services: services,
                  workspaceId: 'ws',
                  onChanged: () => setState(() {}),
                  onRemove: null,
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  return context;
}

Future<void> _pick(WidgetTester tester, String key, String name) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  test('a line picked from the catalogue sends the service\'s identity; an ad-hoc line sends none', () {
    const free = StandaloneLine(description: 'x', quantity: '1', unitCode: 'hour', unitLabel: 'h', unitPrice: '10');
    expect(free.toWire().containsKey('service_id'), isFalse);
    expect(free.withService('svc-1', supply: 'general').toWire()['service_id'], 'svc-1');
    expect(free.withService('svc-1', supply: 'general').supply, 'general');
    expect(free.withService('svc-1').withService(null).toWire().containsKey('service_id'), isFalse);
    expect(free.withGoods((itemId: 'item-1', tags: const [])).withService('svc-1').toWire().containsKey('service_id'), isFalse,
        reason: 'a goods line names no service');
  });

  for (final (label, size) in [('390 wide', const Size(390, 900)), ('1440 wide', const Size(1440, 900))]) {
    group(label, () {
      testWidgets('a service fills the line in: name, gross price, rate and supply, and keeps its identity', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);

        await _pick(tester, 'standalone-line-0-service', 'Coaching');
        expect(tester.takeException(), isNull);
        final wire = form.toLine(context).toWire();
        expect(wire['service_id'], 'svc-coaching');
        expect(wire['description'], 'Coaching');
        expect(wire['unit_price'], '120.00');
        expect(wire['basis'], 'gross');
        expect(wire['vat_rate_id'], 'rate-red');
        expect(wire['supply'], 'general');
      });

      testWidgets('what was typed stays: a description of the person\'s own is kept, and every filled field can still be edited', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        await tester.enterText(find.byKey(const ValueKey('standalone-line-0-description')), 'Two hours with Ana');
        await _pick(tester, 'standalone-line-0-service', 'Coaching');
        await tester.enterText(find.byKey(const ValueKey('standalone-line-0-price')), '99');
        await tester.pump();

        final wire = form.toLine(context).toWire();
        expect(wire['description'], 'Two hours with Ana');
        expect(wire['unit_price'], '99');
        expect(wire['service_id'], 'svc-coaching', reason: 'the identity stays while the agreed price is edited');
      });

      testWidgets('another service replaces the name it had filled in; "no service" frees the line and keeps what it holds', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        await _pick(tester, 'standalone-line-0-service', 'Coaching');
        await _pick(tester, 'standalone-line-0-service', 'Desk day');
        expect(form.toLine(context).toWire()['description'], 'Desk day');

        await _pick(tester, 'standalone-line-0-service', 'No service (free line)');
        final wire = form.toLine(context).toWire();
        expect(wire.containsKey('service_id'), isFalse);
        expect(wire['description'], 'Desk day');
        expect(wire['unit_price'], '15.00');
      });

      testWidgets('a service retired since stays on the line that holds it, and is not offered again', (tester) async {
        final form = StandaloneLineForm(
          from: const StandaloneLine(description: 'Old workshop', quantity: '1', unitCode: 'hour', unitLabel: 'h', unitPrice: '50', serviceId: 'svc-old'),
        );
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        expect(find.byKey(const ValueKey('standalone-line-0-service')), findsOneWidget);
        expect(form.toLine(context).toWire()['service_id'], 'svc-old');
        await tester.tap(find.byKey(const ValueKey('standalone-line-0-service')));
        await tester.pumpAndSettle();
        expect(find.text('Old workshop'), findsWidgets);
        expect(find.text('Coaching'), findsOneWidget);
      });

      testWidgets('a line with no catalogue offers no service choice', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        await _pump(tester, form, size: size, services: const []);
        expect(find.byKey(const ValueKey('standalone-line-0-service')), findsNothing);
      });

      testWidgets('choosing goods gives the service up', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        await _pick(tester, 'standalone-line-0-service', 'Coaching');
        await _pick(tester, 'standalone-line-0-goods', 'Mugs');
        final wire = form.toLine(context).toWire();
        expect(wire.containsKey('service_id'), isFalse);
        expect(wire['item_id'], 'item-mugs');
        expect(find.byKey(const ValueKey('standalone-line-0-service')), findsNothing, reason: 'a goods line is not picked from the services');
      });
    });
  }
}
