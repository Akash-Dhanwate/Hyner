import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/data/inventory_codec.dart';
import 'package:hyner/features/inventory/domain/product.dart';

void main() {
  Map<String, dynamic> saved() => {
    'sku': 'TEST-1',
    'name': 'Test product',
    'nameKey': 'test product',
    'category': '',
    'currency': 'INR',
    'costMinor': 1020,
    'priceMinor': 12345,
    'quantity': 10,
    'reorderLevel': 2,
    'archived': false,
    'revision': 1,
    'lastMovementId': 'opening1',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
  };
  Map<String, dynamic> movement() => {
    'type': 'opening',
    'beforeQuantity': 0,
    'afterQuantity': 10,
    'delta': 10,
    'reason': 'Opening stock',
    'actorUid': 'alice',
    'revision': 1,
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
  };

  test('money parsing is exact and never passes through doubles', () {
    expect(parseMoney('0.10'), 10);
    expect(parseMoney('0012.3'), 1230);
    expect(parseMoney('9999999999.99'), maxMoneyMinor);
    expect(moneyDecimal(12345), '123.45');
    expect(formatMoney(10, 'INR'), 'INR 0.10');
  });
  test('money rejects signs, scientific notation, excess precision and oversized values', () {
    for (final text in [
      '-1',
      '+1',
      '1.005',
      '1e3',
      'NaN',
      'Infinity',
      '.5',
      '1.',
      '10000000000',
      '1,000',
      '',
    ]) {
      expect(() => parseMoney(text), throwsA(isA<AppFailure>()), reason: text);
    }
  });
  test('units reject fractional, signed and out-of-range stock', () {
    expect(parseUnits('0'), 0);
    expect(parseUnits('$maxStock'), maxStock);
    for (final text in ['1.1', '-1', '+1', '1e2', '1000000001', '']) {
      expect(() => parseUnits(text), throwsA(isA<AppFailure>()), reason: text);
    }
    expect(() => parseUnits('0', allowZero: false), throwsA(isA<AppFailure>()));
  });
  test('product code normalization is deterministic', () {
    expect(normalizeSku(' item_1-a '), 'ITEM_1-A');
  });
  test('product decoder preserves fields and timestamps', () {
    final product = InventoryCodec.product('TEST-1', saved());
    expect(product.priceMinor, 12345);
    expect(product.createdAt.millisecondsSinceEpoch, 1000);
    expect(product.isLowStock, isFalse);
  });
  test('product decoder rejects schema changes and mismatched identity', () {
    expect(
      () => InventoryCodec.product('OTHER', saved()),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => InventoryCodec.product('TEST-1', {...saved(), 'extra': 1}),
      throwsA(isA<AppFailure>()),
    );
    final value = saved()..remove('category');
    expect(
      () => InventoryCodec.product('TEST-1', value),
      throwsA(isA<AppFailure>()),
    );
  });
  test('product decoder rejects invalid prices, currency and normalized search keys', () {
    for (final change in [
      {'priceMinor': 1.5},
      {'costMinor': -1},
      {'currency': 'UNKNOWN'},
      {'nameKey': 'different'},
    ]) {
      expect(
        () => InventoryCodec.product('TEST-1', {...saved(), ...change}),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test('product decoder rejects impossible stock, archived balances and timestamps', () {
    for (final change in [
      {'quantity': -1},
      {'quantity': 1.2},
      {'archived': true},
      {'revision': 0},
      {'updatedAt': Timestamp.fromMillisecondsSinceEpoch(0)},
      {'lastMovementId': '../other'},
    ]) {
      expect(
        () => InventoryCodec.product('TEST-1', {...saved(), ...change}),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test(
    'low stock uses the stored threshold and applies only to active products',
    () {
      expect(
        InventoryCodec.product('TEST-1', {
          ...saved(),
          'quantity': 2,
        }).isLowStock,
        isTrue,
      );
      expect(
        InventoryCodec.product('TEST-1', {
          ...saved(),
          'quantity': 0,
          'archived': true,
        }).isLowStock,
        isFalse,
      );
    },
  );
  test(
    'movement decoder validates actual balance changes and account ownership',
    () {
      final entry = InventoryCodec.movement('opening1', 'alice', movement());
      expect(entry.delta, 10);
      for (final change in [
        {'actorUid': 'bob'},
        {'delta': 20},
        {'type': 'sale'},
        {'beforeQuantity': 1},
        {'reason': ' '},
      ]) {
        expect(
          () => InventoryCodec.movement('opening1', 'alice', {
            ...movement(),
            ...change,
          }),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test('adjustments reject zero changes and opening-style revisions', () {
    for (final change in [
      {'type': 'adjustment', 'revision': 1},
      {'type': 'adjustment', 'revision': 2, 'beforeQuantity': 10, 'delta': 0},
    ]) {
      expect(
        () => InventoryCodec.movement('adjust1', 'alice', {
          ...movement(),
          ...change,
        }),
        throwsA(isA<AppFailure>()),
      );
    }
  });
}
