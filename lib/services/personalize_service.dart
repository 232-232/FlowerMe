import 'package:firebase_database/firebase_database.dart';

class PersonalizeService {
  static void logFavorite(String phone, String productId, bool isAdded) {
    if (productId.isEmpty) return;
    final p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10) return;
    final num = p.substring(p.length - 10);
    final safeId = productId.replaceAll(RegExp(r'[.#$\[\]]'), '_');
    final ref = FirebaseDatabase.instance.ref('root/userpersonalize/$num/favorite/$safeId');
    if (isAdded) {
      ref.set(DateTime.now().toIso8601String()).catchError((_) {});
    } else {
      ref.remove().catchError((_) {});
    }
  }

  static void logSearch(String phone, String query) {
    final p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10 || query.trim().isEmpty) return;
    final num = p.substring(p.length - 10);
    final safeQuery = query.replaceAll(RegExp(r'[.#$\[\]]'), '_');
    FirebaseDatabase.instance.ref('root/userpersonalize/$num/searched/$safeQuery').set(DateTime.now().toIso8601String()).catchError((_) {});
  }

  static void logShare(String phone, String productId) {
    if (productId.isEmpty) return;
    final p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10) return;
    final num = p.substring(p.length - 10);
    final safeId = productId.replaceAll(RegExp(r'[.#$\[\]]'), '_');
    FirebaseDatabase.instance.ref('root/userpersonalize/$num/shared/$safeId').set(DateTime.now().toIso8601String()).catchError((_) {});
  }
}
