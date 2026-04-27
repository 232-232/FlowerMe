import 'dart:io';

void main() {
  final file = File('lib/pages/items_page.dart');
  final lines = file.readAsLinesSync();
  // Remove lines 893 to 1281 (0-indexed: 892 to 1280 inclusive)
  lines.removeRange(892, 1281);
  file.writeAsStringSync(lines.join('\n') + '\n');
  print('Done removing lines');
}
