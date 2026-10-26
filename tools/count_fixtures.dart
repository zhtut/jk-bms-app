// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final src = File('test/protocol_test.dart').readAsStringSync();
  for (final name in ['_jk02CellHex', '_jk04CellHex', '_deviceInfoHex']) {
    final start = src.indexOf('const $name =');
    final end = src.indexOf(';', start);
    final body = src.substring(start, end);
    final strs = RegExp("'([^']*)'")
        .allMatches(body)
        .map((m) => m.group(1)!)
        .join(' ');
    final toks = strs
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    print('$name: ${toks.length} bytes; last=${toks.last}');
  }
}
