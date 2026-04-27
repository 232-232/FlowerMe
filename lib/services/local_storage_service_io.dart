import 'package:shared_preferences/shared_preferences.dart';

/// Native (Android/iOS/desktop) implementation — uses SharedPreferences.
abstract final class LocalStorageService {
  LocalStorageService._();

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<String?> getString(String key) async {
    final prefs = await _instance();
    return prefs.getString(key);
  }

  static Future<bool> setString(String key, String value) async {
    final prefs = await _instance();
    return prefs.setString(key, value);
  }

  static Future<bool> remove(String key) async {
    final prefs = await _instance();
    return prefs.remove(key);
  }

  static Future<bool> containsKey(String key) async {
    final prefs = await _instance();
    return prefs.containsKey(key);
  }
}
