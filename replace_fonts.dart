import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = await file.readAsString();
    bool changed = false;

    if (content.contains('GoogleFonts.plusJakartaSansTextTheme(')) {
      content = content.replaceAll('GoogleFonts.plusJakartaSansTextTheme(', 'Theme.of(context).textTheme.copyWith(');
      changed = true;
    }
    
    // Check if the file still has GoogleFonts references
    if (content.contains('GoogleFonts.plusJakartaSans(')) {
      content = content.replaceAll('GoogleFonts.plusJakartaSans(', 'TextStyle(fontFamily: "PlusJakartaSans", ');
      content = content.replaceAll('TextStyle(fontFamily: "PlusJakartaSans", )', 'TextStyle(fontFamily: "PlusJakartaSans")');
      changed = true;
    }

    // Also remove import
    if (content.contains("package:google_fonts/google_fonts.dart")) {
      content = content.replaceAll("import 'package:google_fonts/google_fonts.dart';", "");
      content = content.replaceAll("import \"package:google_fonts/google_fonts.dart\";", "");
      changed = true;
    }

    if (changed) {
      await file.writeAsString(content);
      print('Updated \${file.path}');
    }
  }
}
