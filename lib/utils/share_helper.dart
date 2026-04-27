import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/category_model.dart';
import '../widgets/items/item_card_product.dart';

class ShareHelper {
  /// Base host for deep linking.
  static const String baseUrl = 'https://dailyclub.in';

  /// Download an image from URL and save it to a temporary file.
  static Future<File?> _downloadImageToTemp(String url, String fileName) async {
    try {
      if (url.isEmpty) return null;
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('Error downloading image for share: $e');
    }
    return null;
  }

  /// Share a product item with its image and link.
  static Future<void> shareProduct(Product product) async {
    return _shareProductData(product.name, product.image, product.productCode);
  }

  /// Share an ItemCardProduct (used in ItemsPage).
  static Future<void> shareItemCardProduct(ItemCardProduct product) async {
    return _shareProductData(product.name, product.image, product.productCode);
  }

  static Future<void> _shareProductData(String name, String image, String code) async {
    final link = '$baseUrl/item/$code';
    final text = 'Check out $name on Daily Club!\n$link';
    
    if (kIsWeb) {
      try {
        await Share.share(text);
      } catch (e) {
        debugPrint('Web share failed: $e');
        await Clipboard.setData(ClipboardData(text: text));
      }
      return;
    }

    final imageFile = await _downloadImageToTemp(image, 'share_item_$code.png');
    
    if (imageFile != null) {
      await Share.shareXFiles([XFile(imageFile.path)], text: text);
    } else {
      await Share.share(text);
    }
  }

  /// Share a category.
  static Future<void> shareCategory(String categoryName, {String? categoryCode, String? categoryImage}) async {
    final link = categoryCode != null ? '$baseUrl/category/$categoryCode' : baseUrl;
    final text = 'Browse $categoryName on Daily Club! 🛒\n$link';

    if (kIsWeb) {
      try {
        await Share.share(text);
      } catch (e) {
        debugPrint('Web share failed: $e');
        await Clipboard.setData(ClipboardData(text: text));
      }
      return;
    }

    if (categoryImage != null && categoryImage.isNotEmpty) {
      final imageFile = await _downloadImageToTemp(categoryImage, 'share_cat_${categoryName.replaceAll(" ", "_")}.png');
      if (imageFile != null) {
        await Share.shareXFiles([XFile(imageFile.path)], text: text);
        return;
      }
    }
    
    await Share.share(text);
  }

  /// Capture a widget to an image and share it.
  static Future<void> shareWidget(Widget widget, {required BuildContext context, String? customText}) async {
    final text = customText ?? 'Check out this Exclusive Deal on Daily Club!\n$baseUrl';

    if (kIsWeb) {
      try {
        await Share.share(text);
      } catch (e) {
        debugPrint('Web share failed: $e');
        await Clipboard.setData(ClipboardData(text: text));
        // Provide user feedback that it copied.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard!')),
        );
      }
      return;
    }

    try {
      final screenshotController = ScreenshotController();
      // Render the widget matching the current media query size
      final Uint8List? imageBytes = await screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: widget,
          ),
        ),
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/exclusive_share_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(imageBytes);

        await Share.shareXFiles([XFile(file.path)], text: text);
      }
    } catch (e) {
      debugPrint('Error sharing widget: $e');
    }
  }
}
