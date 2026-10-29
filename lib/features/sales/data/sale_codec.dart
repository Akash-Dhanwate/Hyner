import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inventory/data/inventory_codec.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';

abstract final class SaleCodec {
  static Sale decode(String id, String uid, Map<String, dynamic>? data) {
    try {
      if (!InventoryCodec.validOperationId(id) ||
          data == null ||
          data.length != 5 ||
          data['actorUid'] != uid ||
          data['createdAt'] is! Timestamp ||
          data['currency'] is! String ||
          data['totalMinor'] is! int ||
          data['items'] is! Map) {
        throw const FormatException();
      }
      final items = data['items'] as Map;
      final lines = <SaleLine>[];
      for (final entry in items.entries) {
        final item = entry.value;
        if (entry.key is! String ||
            item is! Map ||
            item.length < 4 ||
            item.length > 5 ||
            item['name'] is! String ||
            item['unitPriceMinor'] is! int ||
            item['quantity'] is! int ||
            item['totalMinor'] is! int ||
            item['parameters'] != null &&
                (item['parameters'] is! List ||
                    (item['parameters'] as List).any(
                      (entry) =>
                          entry is! Map ||
                          entry['name'] is! String ||
                          entry['value'] is! String,
                    ))) {
          throw const FormatException();
        }
        final line = SaleLine(
          sku: entry.key as String,
          name: item['name'] as String,
          unitPriceMinor: item['unitPriceMinor'] as int,
          quantity: item['quantity'] as int,
          parameters: [
            for (final entry in (item['parameters'] as List? ?? const []))
              ProductParameter.fromMap(entry as Map<dynamic, dynamic>),
          ],
        );
        line.validate();
        if (item['totalMinor'] != line.totalMinor) {
          throw const FormatException();
        }
        lines.add(line);
      }
      final draft = SaleDraft(
        currency: data['currency'] as String,
        lines: lines,
      )..validate();
      if (draft.totalMinor != data['totalMinor']) throw const FormatException();
      return Sale(
        id: id,
        draft: draft,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
      );
    } catch (_) {
      throw inventoryInvalid(
        'This sale could not be read safely. Refresh sales or contact support.',
      );
    }
  }
}
