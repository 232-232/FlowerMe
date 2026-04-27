import 'package:firebase_database/firebase_database.dart';

import '../debug/dc_log.dart';
import '../debug/perf_logger.dart';
import '../models/firebase_product_model.dart';

/// Streams products from [root/products] filtered by [categoryCode].
///
/// Each product node is expected to contain a `categoryCode` field whose value
/// matches the code used in [root/category/{categoryCode}].
class ProductProvider {
  ProductProvider._();

  /// Returns a stream of products belonging to [categoryCode].
  /// Emits a new list whenever the Firebase snapshot changes.
  static Stream<List<FirebaseProductModel>> productsStream(
    String categoryCode,
  ) {
    if (categoryCode.isEmpty) {
      return const Stream.empty();
    }

    final ref = FirebaseDatabase.instance.ref('root/products');
    dcLog('Firebase', '🔌 Connecting to root/products (filter: $categoryCode)…');
    Perf.start('Firebase', 'ItemsPage product data');

    return ref.onValue.map((event) {
      final snapshot = event.snapshot;

      if (!snapshot.exists || snapshot.value == null) {
        dcLog('Firebase', '⚠️  root/products snapshot is empty');
        return <FirebaseProductModel>[];
      }

      final raw = snapshot.value as Map<Object?, Object?>;
      final products = <FirebaseProductModel>[];

      for (final entry in raw.entries) {
        final code = entry.key?.toString() ?? '';
        final data = entry.value;

        if (data is! Map<Object?, Object?>) continue;

        final model = FirebaseProductModel.fromSnapshot(code, data);

        if (model.categoryCode == categoryCode) {
          products.add(model);
          dcLog(
            'Product',
            '📦 [$code] "${model.name}" price:${model.price} cat:${model.categoryCode}',
          );
        }
      }

      dcLog(
        'Firebase',
        '📋 Products for "$categoryCode": ${products.length}',
      );
      Perf.end('Firebase', 'ItemsPage product data');
      return products;
    });
  }
}
