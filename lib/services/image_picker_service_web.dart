import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation — creates a hidden <input type="file"> element and
/// reads the selected image bytes directly via the FileReader API.
/// No platform channel, no plugin required.
abstract final class ImagePickerService {
  ImagePickerService._();

  static Future<Uint8List?> pickImageBytes() {
    final completer = Completer<Uint8List?>();

    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';

    // Must be in the DOM before .click() in some browsers.
    html.document.body?.append(input);

    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = html.FileReader();

      reader.onLoad.listen((_) {
        final result = reader.result;
        Uint8List? bytes;
        if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is Uint8List) {
          bytes = result;
        }
        input.remove();
        if (!completer.isCompleted) completer.complete(bytes);
      });

      reader.onError.listen((_) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
      });

      reader.readAsArrayBuffer(files.first);
    });

    input.click();
    return completer.future;
  }
}
