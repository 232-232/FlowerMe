import 'dart:io';

void main() async {
  final result = await Process.run('dart', ['analyze', '--format=machine']);
  File('real_errors.txt').writeAsStringSync(result.stdout.toString() + "\n" + result.stderr.toString());
}
