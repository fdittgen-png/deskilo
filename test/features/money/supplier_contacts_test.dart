// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- the contacts of a supplier under the rules the server applies: a name, a role of the business, a valid e-mail; one preferred
// purchasing contact with an e-mail; a retired contact is no longer preferred; a role name is kept once; the terms are in range.
import 'package:deskilo/features/money/application/supplier_contact_commands.dart';
import 'package:deskilo/features/money/data/in_memory_supplier_contact_repository.dart';
import 'package:deskilo/features/money/domain/supplier_contact.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws';
const _supplier = 's1';

void main() {
  late InMemorySupplierContacts repo;
  late SupplierContactCommands commands;
  late String orders;
  late String delivery;

  setUp(() async {
    repo = InMemorySupplierContacts();
    commands = SupplierContactCommands(repo);
    final roles = await repo.roles(_ws);
    orders = roles.firstWhere((r) => r.code == BuiltInContactRole.orders).id;
    delivery = roles.firstWhere((r) => r.code == BuiltInContactRole.delivery).id;
  });

  Future<SupplierContactProblem?> add(String name, String email, {bool preferred = false, String? role}) =>
      commands.saveContact(_ws, supplierId: _supplier, name: name, roleId: role ?? orders, email: email, preferred: preferred);

  test('a business starts with five roles in order', () async {
    final roles = await repo.roles(_ws);
    expect([for (final r in roles) r.code], BuiltInContactRole.codes);
  });

  test('a contact is added; a preferred one frees the previous preferred', () async {
    expect(await add('Ana', 'ana@acme.test', preferred: true), isNull);
    expect(await add('Bob', 'bob@acme.test', preferred: true), isNull);
    final preferred = [for (final c in await repo.contacts(_ws, _supplier)) if (c.preferred) c.name];
    expect(preferred, ['Bob']);
  });

  test('refusals: no name, a malformed e-mail, a preferred one without e-mail', () async {
    expect(await add('  ', ''), SupplierContactProblem.nameRequired);
    expect(await add('Cy', 'nope'), SupplierContactProblem.emailInvalid);
    expect(await add('Cy', '', preferred: true), SupplierContactProblem.preferredNeedsEmail);
    expect(await repo.contacts(_ws, _supplier), isEmpty);
  });

  test('a role of another business is refused', () async {
    expect(await add('Cy', '', role: 'unknown'), SupplierContactProblem.failed);
  });

  test('retiring the preferred contact leaves none preferred, and it can be brought back', () async {
    await add('Ana', 'ana@acme.test', preferred: true);
    final id = (await repo.contacts(_ws, _supplier)).single.id;
    expect(await commands.setContactRetired(_ws, id, retired: true), isNull);
    final c = (await repo.contacts(_ws, _supplier)).single;
    expect(c.retired, isTrue);
    expect(c.preferred, isFalse);
    expect(await commands.setContactRetired(_ws, id, retired: false), isNull);
    expect((await repo.contacts(_ws, _supplier)).single.retired, isFalse);
  });

  test('a role is added, its name is kept once, and a retired one frees the name', () async {
    expect(await commands.saveRole(_ws, label: 'Quality'), isNull);
    expect(await commands.saveRole(_ws, label: ' quality '), SupplierContactProblem.nameTaken);
    expect(await commands.saveRole(_ws, label: ''), SupplierContactProblem.nameRequired);
    final quality = (await repo.roles(_ws)).firstWhere((r) => r.label == 'Quality');
    expect(await commands.setRoleRetired(_ws, quality.id, retired: true), isNull);
    expect(await commands.saveRole(_ws, label: 'Quality'), isNull);
  });

  test('a contact keeps a role retired after it was given', () async {
    await add('Ana', 'ana@acme.test', role: delivery);
    await commands.setRoleRetired(_ws, delivery, retired: true);
    final c = (await repo.contacts(_ws, _supplier)).single;
    expect(await add('Ana', 'ana2@acme.test', role: delivery), SupplierContactProblem.failed);
    expect(
      await commands.saveContact(_ws, id: c.id, supplierId: _supplier, name: 'Ana', roleId: delivery, email: 'ana2@acme.test'),
      isNull,
    );
  });

  test('the terms are kept, and out-of-range ones are refused', () async {
    expect(await commands.saveTerms(_ws, _supplier, const SupplierTerms(orderCurrency: 'CHF', paymentTermDays: 30, orderLeadDays: 5)), isNull);
    final t = await repo.terms(_ws, _supplier);
    expect((t.orderCurrency, t.paymentTermDays, t.orderLeadDays), ('CHF', 30, 5));
    expect(await commands.saveTerms(_ws, _supplier, const SupplierTerms(paymentTermDays: 400)), SupplierContactProblem.termsInvalid);
    expect(await commands.saveTerms(_ws, _supplier, const SupplierTerms(orderCurrency: 'chf')), SupplierContactProblem.termsInvalid);
  });
}
