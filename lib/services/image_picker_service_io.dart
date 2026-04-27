import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Native (Android/iOS/desktop) implementation — uses the image_picker plugin.
abstract final class ImagePickerService {
  ImagePickerService._();

  static Future<Uint8List?> pickImageBytes() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
