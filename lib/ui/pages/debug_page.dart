import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';

/// 调试页: 原始帧收发日志 (hex), 用于比对官方 App / 逆向未解析字段
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final _scrollController = ScrollController();
  bool autoScroll = true;
  int? expandedIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _hexDump(List<int> bytes) {
    final sb = StringBuffer();
    for (int i = 0; i < bytes.length; i += 16) {
      sb.write(i.toRadixString(16).padLeft(4, '0').toUpperCase());
      sb.write('  ');
      final end = (i + 16).clamp(0, bytes.length);
      for (int j = i; j < end; j++) {
        sb.write(bytes[j].toRadixString(16).padLeft(2, '0').toUpperCase());
        sb.write(j == end - 1 ? '' : ' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final frames = c.rawFrames;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (autoScroll && frames.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.terminal_rounded,
                  size: 16, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 6),
              Text('${frames.length} 帧 (最多保留 ${AppController.maxRawFrames})',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54)),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('自动滚动', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: autoScroll,
                    onChanged: (v) => setState(() => autoScroll = v),
                  ),
                ],
              ),
              IconButton(
                tooltip: '复制全部',
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                onPressed: frames.isEmpty
                    ? null
                    : () {
                        final text = frames
                            .map((f) =>
                                '# ${f.ts.toIso8601String()} ${f.direction} ${f.label}\n${_hexDump(f.bytes)}')
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')));
                      },
              ),
              IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                onPressed: c.clearRawFrames,
              ),
            ],
          ),
        ),
        Expanded(
          child: frames.isEmpty
              ? const Center(
                  child: Text('暂无帧记录',
                      style: TextStyle(color: AppColors.gray, fontSize: 13)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: frames.length,
                  itemBuilder: (_, i) =>
                      _frameTile(frames[i], i, isDark),
                ),
        ),
      ],
    );
  }

  Widget _frameTile(RawFrameEntry f, int index, bool isDark) {
    final isRx = f.direction == 'rx';
    final isTx = f.direction == 'tx';
    final color = isTx
        ? AppColors.primary
        : isRx
            ? AppColors.green
            : AppColors.red;
    final expanded = expandedIndex == index;
    final time =
        '${f.ts.hour.toString().padLeft(2, '0')}:${f.ts.minute.toString().padLeft(2, '0')}:${f.ts.second.toString().padLeft(2, '0')}.${f.ts.millisecond.toString().padLeft(3, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => expandedIndex = expanded ? null : index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isRx ? 'RX' : isTx ? 'TX' : '!!',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 8),
                  Text(time,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f.label,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${f.bytes.length}B',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38)),
                  Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.gray),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _hexDump(f.bytes),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                      color: isDark ? Colors.green.shade200 : const Color(0xFF2E4057),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
