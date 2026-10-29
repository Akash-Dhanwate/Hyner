import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/data/inventory_codec.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/data/sale_codec.dart';
import 'package:hyner/features/sales/domain/sale.dart';

SaleLine line({String sku = 'A', int quantity = 2, int price = 1010}) =>
    SaleLine(
      sku: sku,
      name: 'Test item',
      unitPriceMinor: price,
      quantity: quantity,
    );
void main() {
  test('bill uses exact minor-unit arithmetic and immutable lines', () {
    final lines = [line(), line(sku: 'B', quantity: 3, price: 1550)];
    final draft = SaleDraft(currency: 'INR', lines: lines)..validate();
    lines.clear();
    expect(draft.totalMinor, 6670);
    expect(draft.units, 5);
    expect(formatMoney(draft.totalMinor, draft.currency), 'INR 66.70');
    expect(() => draft.lines.clear(), throwsUnsupportedError);
  });
  test('bills can contain 100 different products', () {
    final draft = SaleDraft(
      currency: 'INR',
      lines: List.generate(100, (i) => line(sku: 'ITEM-$i')),
    )..validate();
    expect(draft.lines.length, 100);
    expect(draft.totalMinor, 202000);
  });
  test('zero prices are allowed; zero and negative quantities are not', () {
    SaleDraft(currency: 'INR', lines: [line(price: 0)]).validate();
    for (final quantity in [0, -1, maxStock + 1]) {
      expect(
        () => line(quantity: quantity).validate(),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test('rejects empty, duplicate lines and unsupported currency', () {
    for (final draft in [
      SaleDraft(currency: 'INR', lines: []),
      SaleDraft(currency: 'INR', lines: [line(), line()]),
      SaleDraft(currency: 'XXX', lines: [line()]),
    ]) {
      expect(draft.validate, throwsA(isA<AppFailure>()));
    }
  });
  test(
    'rejects overflowing multiplication before computing monetary totals',
    () {
      expect(
        () => line(quantity: maxStock, price: maxMoneyMinor).validate(),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => SaleDraft(
          currency: 'INR',
          lines: [
            line(price: maxMoneyMinor, quantity: 1),
            line(sku: 'B', price: 1, quantity: 1),
          ],
        ).validate(),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('idempotency comparison ignores order but detects price and quantity changes', () {
    final a = SaleDraft(
      currency: 'INR',
      lines: [
        line(),
        line(sku: 'B'),
      ],
    );
    expect(
      a.matches(
        SaleDraft(
          currency: 'INR',
          lines: [
            line(sku: 'B'),
            line(),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      a.matches(
        SaleDraft(
          currency: 'INR',
          lines: [
            line(sku: 'B'),
            line(quantity: 1),
          ],
        ),
      ),
      isFalse,
    );
  });
  test(
    'sale decoding rejects corrupted totals, types and account identity',
    () {
      final draft = SaleDraft(currency: 'INR', lines: [line()]);
      final data = {
        'actorUid': 'alice',
        'currency': 'INR',
        'items': draft.items,
        'totalMinor': draft.totalMinor,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
      };
      expect(SaleCodec.decode('sale1', 'alice', data).draft.totalMinor, 2020);
      for (final change in [
        {'totalMinor': 1},
        {'actorUid': 'bob'},
        {'createdAt': 'today'},
        {'extra': true},
        {
          'items': {
            'A': {...line().toMap(), 'quantity': 2.5},
          },
        },
      ]) {
        expect(
          () => SaleCodec.decode('sale1', 'alice', {...data, ...change}),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'inventory history reads sale deductions and rejects forged sale reason',
    () {
      final data = {
        'type': 'sale',
        'beforeQuantity': 5,
        'afterQuantity': 3,
        'delta': -2,
        'reason': 'Sale sale1',
        'actorUid': 'alice',
        'revision': 2,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
      };
      expect(InventoryCodec.movement('sale1', 'alice', data).type, 'sale');
      expect(
        () => InventoryCodec.movement('sale1', 'alice', {
          ...data,
          'reason': 'Other',
        }),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
