/// Selects the correct storage backend at compile time:
///   • Web  → dart:html window.localStorage  (no platform channel)
///   • Other → SharedPreferences             (platform channel)
export 'local_storage_service_io.dart'
    if (dart.library.html) 'local_storage_service_web.dart';
