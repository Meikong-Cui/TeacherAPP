import 'package:flutter/material.dart';

/// 听障评估四种符号：开始 / 不稳 / 稳定 / 表达。
/// 用于表示儿童在各项能力上的掌握阶段。
class HearingSymbol {
  HearingSymbol._();

  /// 四个符号图片资源（顺序即序号 1-4）。
  static const List<String> assets = [
    'assets/images/hearing_symbols/1开始.png',
    'assets/images/hearing_symbols/2不稳.png',
    'assets/images/hearing_symbols/3稳定.png',
    'assets/images/hearing_symbols/4表达.png',
  ];

  /// 四个符号文字标签（与 assets 顺序一致）。
  static const List<String> labels = ['开始', '不稳', '稳定', '表达'];

  /// 将存储值（int 或数字字符串）解析为符号序号 1-4；非法或空返回 null。
  static int? indexFromValue(dynamic v) {
    if (v == null) return null;
    if (v is int) return (v >= 1 && v <= 4) ? v : null;
    if (v is String) {
      final n = int.tryParse(v);
      return (n != null && n >= 1 && n <= 4) ? n : null;
    }
    return null;
  }
}

/// 四个符号的横向选择器。点击选中，再次点击取消选中。
class SymbolPicker extends StatelessWidget {
  final int? selected; // 1-4 或 null（未选）
  final ValueChanged<int?> onChanged;
  final double size;

  const SymbolPicker({
    required this.selected,
    required this.onChanged,
    this.size = 32,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 4; i++)
          GestureDetector(
            onTap: () => onChanged(selected == i ? null : i),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: selected == i ? primary : Colors.grey.shade300,
                  width: selected == i ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Image.asset(HearingSymbol.assets[i - 1], fit: BoxFit.contain),
              ),
            ),
          ),
      ],
    );
  }
}

/// 评估项行：左侧标签 + 右侧符号选择器。
class SymbolField extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final double symbolSize;

  const SymbolField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.symbolSize = 30,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          SymbolPicker(selected: value, onChanged: onChanged, size: symbolSize),
        ],
      ),
    );
  }
}
