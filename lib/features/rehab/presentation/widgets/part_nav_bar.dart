import 'package:flutter/material.dart';

/// 长表单的「上一部分 / 下一部分」翻页条。
///
/// **为什么必须钉在屏幕底部**：康复评估一张纸表的一页就是几十个格子
/// （1.1.2 持续评估全表 512 格、1.1.1 首次评估一页几十个字段），
/// 若翻页入口只放在内容**开头**，老师滑到底想翻页必须滚回顶部。
/// 实测表现就是「卡在这一页出不去」（2026-09-15 用户反馈）。
///
/// 两个填表页（首次评估 1.1.1 / 持续评估 1.1.2）都用它把翻页条固定在底部、
/// 与「保存」按钮同一区域，任何滚动位置都能翻页。
///
/// 布局刻意用 [Expanded] 夹住中间计数：
///   · 首/末页某一侧没有按钮时，中间计数仍然居中（不会左右跳）；
///   · 文案过长时被约束并由 ellipsis 收尾，窄屏也不会溢出。
class PartNavBar extends StatelessWidget {
  const PartNavBar({
    required this.index,
    required this.count,
    this.onPrev,
    this.onNext,
    this.nextLabel,
    this.prevLabel = '上一部分',
    super.key,
  });

  /// 当前处于第几部分（**0 基**）。
  final int index;

  /// 总部分数。
  final int count;

  /// 为 null 表示已在第一部分 → 不渲染按钮（而不是渲染一个灰按钮）。
  final VoidCallback? onPrev;

  /// 为 null 表示已在最后一部分 → 不渲染按钮。
  final VoidCallback? onNext;

  /// 下一部分按钮文案，默认「下一部分 →」。
  final String? nextLabel;

  final String prevLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: onPrev == null
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: onPrev,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(prevLabel,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
          ),
        ),
        Text('${index + 1} / $count',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: onNext == null
                ? const SizedBox.shrink()
                : FilledButton.tonal(
                    onPressed: onNext,
                    child: Text(nextLabel ?? '下一部分 →',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
          ),
        ),
      ]),
    );
  }
}
