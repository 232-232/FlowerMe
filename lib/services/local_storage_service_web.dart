// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation — uses window.localStorage directly.
/// No platform channel, no plugin, synchronous under the hood.
abstract final class LocalStorageService {
  LocalStorageService._();

  static Future<String?> getString(String key) async =>
      html.window.localStorage[key];

  static Future<bool> setString(String key, String value) async {
    html.window.localStorage[key] = value;
    return true;
  }

  static Future<bool> remove(String key) async {
    html.window.localStorage.remove(key);
    return true;
  }

  static Future<bool> containsKey(String key) async =>
      html.window.localStorage.containsKey(key);
}
