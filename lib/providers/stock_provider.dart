import 'package:firebase_database/firebase_database.dart';

import '../debug/dc_log.dart';
import '../models/stock_variant_model.dart';

/// Streams stock variants from [root/stock/{productCode}].
///
/// Each child key is a variantId (e.g. "01", "02") and contains:
///   offerPrice, mrp, unitValue
class StockProvider {
  StockProvider._();

  /// Returns a stream of [StockVariantModel] list for the given [productCode].
  /// Emits a new list on every Firebase snapshot change.
  static Stream<List<StockVariantModel>> stockStream(String productCode) {
    if (productCode.isEmpty) return const Stream.empty();

    final ref = FirebaseDatabase.instance.ref('root/stock/$productCode');
    dcLog('Firebase', '🔌 Connecting to root/stock/$productCode…');

    return ref.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        dcLog('Firebase', '⚠️  root/stock/$productCode snapshot is empty');
        return <StockVariantModel>[];
      }

      final raw = snapshot.value as Map<Object?, Object?>;
      final variants = <StockVariantModel>[];

      for (final entry in raw.entries) {
        final variantId = entry.key?.toString() ?? '';
        final data = entry.value;
        if (data is! Map<Object?, Object?>) continue;

        final variant = StockVariantModel.fromSnapshot(variantId, data);
        variants.add(variant);
      }

      // Sort by variantId so display order is consistent
      variants.sort((a, b) => a.variantId.compareTo(b.variantId));

      return variants;
    });
  }
}
