// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- an item group proposes the unit its items are bought in and the unit they are sold in, each with what one of it makes of the
// inventory unit, and for the sale unit its price. The group's sheet reads them from the group, sends them, and refuses a unit with no
// factor, a factor with no unit, a unit that is not one of the business's, and a price that is no amount.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/ui/form_controllers.dart';
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/features/stock/presentation/item_group_units.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

const _format = AppFormat(locale: 'en', currencyCode: 'EUR');
final _en = AppLocalizationsEn();

GroupUnitProposals _of(Map<String, String> texts) =>
    GroupUnitProposals(FormControllers({...GroupUnitProposals.initial(null, _format), ...texts}), _format, 'ws-1', builtInUnits);

void main() {
  test('a group reads its proposals back: the factor as one number or a fraction, the price as the member writes it', () {
    const group = ItemGroup(
      id: 'g',
      parentId: null,
      name: 'Mugs',
      revision: 1,
      items: 0,
      params: {
        'default_purchase_unit': 'kg',
        'default_purchase_factor_num': 1,
        'default_purchase_factor_den': 3,
        'default_sale_unit': 'l',
        'default_sale_factor_num': 12,
        'default_sale_factor_den': 1,
        'default_sale_price_cents': 1100,
      },
    );
    expect(GroupUnitProposals.initial(group, _format), {
      'purchaseUnit': 'kg',
      'factor': '1/3',
      'saleUnit': 'l',
      'saleFactor': '12',
      'salePrice': '11.00',
    });
  });

  test('what is sent: the unit, the factor in lowest terms, the price in minor units; nothing set sends nothing', () {
    final p = _of({'saleUnit': 'l', 'saleFactor': '12', 'salePrice': '11.00'}).parameters();
    expect((p['default_sale_unit'], p['default_sale_factor_num'], p['default_sale_factor_den'], p['default_sale_price_cents']), ('l', 12, 1, 1100));
    expect(p['default_purchase_unit'], isNull);
    expect(_of({}).parameters().values.every((v) => v == null), isTrue);
  });

  test('a unit with no factor, a factor with no unit, a unit of nobody and a price that is no amount are refused', () {
    expect(_of({'saleUnit': 'l'}).errors(_en).keys, ['saleFactor']);
    expect(_of({'saleFactor': '12'}).errors(_en).keys, ['saleUnit']);
    expect(_of({'saleUnit': 'zzz', 'saleFactor': '1'}).errors(_en).keys, ['saleUnit']);
    expect(_of({'salePrice': 'abc'}).errors(_en).keys, ['salePrice']);
    expect(_of({'saleUnit': 'l', 'saleFactor': '12', 'salePrice': '11.00'}).errors(_en), isEmpty);
  });
}
