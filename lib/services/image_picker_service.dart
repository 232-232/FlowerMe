/// Selects the correct image-picker backend at compile time:
///   • Web  → dart:html FileUploadInputElement  (no platform channel)
///   • Other → image_picker plugin              (platform channel)
export 'image_picker_service_io.dart'
    if (dart.library.html) 'image_picker_service_web.dart';
