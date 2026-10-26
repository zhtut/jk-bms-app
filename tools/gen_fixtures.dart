// ignore_for_file: avoid_print
// 从 refs/esphome-jk-bms/jk_bms_ble.cpp 的注释中提取真实抓包帧,
// 生成 test/fixtures.dart (避免手工转录错误)。
// 用法: dart run tools/gen_fixtures.dart
import 'dart:io';

List<int> extractHex(List<String> lines) {
  final bytes = <int>[];
  for (final line in lines) {
    final tokens = line
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.startsWith('0x') || RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(t));
    for (final t in tokens) {
      final hex = t.startsWith('0x') ? t.substring(2) : t;
      if (hex.length == 2) {
        bytes.add(int.parse(hex, radix: 16));
      }
    }
  }
  return bytes;
}

int crc(List<int> data) {
  int s = 0;
  for (int i = 0; i < 299; i++) {
    s = (s + data[i]) & 0xFF;
  }
  return s;
}

void main() {
  final cpp = File('refs/esphome-jk-bms/jk_bms_ble.cpp').readAsLinesSync();

  // 行号 (1-based) -> 0-based 索引
  final jk02Cell = extractHex(cpp.sublist(693, 696)); // 行 694-696
  final jk04Cell = extractHex(cpp.sublist(986, 1000)); // 行 987-1000
  final deviceInfo = extractHex(cpp.sublist(1648, 1662)); // 行 1649-1662

  void check(String name, List<int> f) {
    final ok = f.length == 300 && crc(f) == f[299];
    print('$name: ${f.length} bytes, byte[299]=0x${f.length == 300 ? f[299].toRadixString(16) : '?'}, '
        'crc=${f.length == 300 ? '0x${crc(f).toRadixString(16)}' : '?'}, '
        'valid=$ok, type=0x${f.length > 4 ? f[4].toRadixString(16) : '?'}');
    if (!ok) {
      stderr.writeln('!! $name 校验失败');
      exitCode = 1;
    }
  }

  check('jk02CellInfo', jk02Cell);
  check('jk04CellInfo', jk04Cell);
  check('deviceInfo', deviceInfo);

  String dartConst(String name, List<int> bytes) {
    final sb = StringBuffer("const $name =\n");
    for (int i = 0; i < bytes.length; i += 16) {
      final end = (i + 16).clamp(0, bytes.length);
      final row = bytes
          .sublist(i, end)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      sb.write("    '$row");
      sb.write(i + 16 < bytes.length ? " '\n" : "';\n");
    }
    return sb.toString();
  }

  final out = StringBuffer();
  out.writeln('// 自动生成: dart run tools/gen_fixtures.dart');
  out.writeln('// 来源: syssi/esphome-jk-bms jk_bms_ble.cpp 注释中的真实设备抓包帧');
  out.writeln('// 所有帧均通过 CRC 校验 (300 字节, sum mod 256 @ byte 299)');
  out.writeln();
  out.write(dartConst('jk02CellInfoHex', jk02Cell));
  out.writeln();
  out.write(dartConst('jk04CellInfoHex', jk04Cell));
  out.writeln();
  out.write(dartConst('deviceInfoHex', deviceInfo));
  File('test/fixtures.dart').writeAsStringSync(out.toString());
  print('test/fixtures.dart 已生成');
}
