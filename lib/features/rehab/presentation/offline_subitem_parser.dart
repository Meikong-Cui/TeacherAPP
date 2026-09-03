import 'dart:convert';

/// 线下模板报告「康复目标 / 指导说明」文本解析工具。
///
/// 文本形如：
///   操作模仿
///   1、结合节奏明显的音乐旋律……
///   2、模仿用小棒物件……
///   语言模仿
///   1、结合动作模仿说出……
///
/// 规则（前后端须一致）：
/// - 以数字编号开头的行（如 `1、` `2.` `③`）视为一个「小项」，按顺序编号 0,1,2…
/// - 不以数字编号开头的行（如「操作模仿」）视为分类标题，不参与勾选，
///   但当其下没有任何被选中的小项时，该标题会被一并剔除。
/// - 过滤时只保留被选中的小项；某小项被剔除后，其原始编号保留（不重新编号）。
/// - 整段文本没有任何编号小项时（家长版概括式段落）原样返回，不清空。
///
/// 前后端（Java / Dart）必须采用完全相同的编号识别与过滤规则，
/// 否则前端算出的小项序号与后端过滤无法对齐。

final RegExp _numberedLine = RegExp(r'^\s*\d+\s*[、.．.)\]）]');
final RegExp _circledLine = RegExp(r'^\s*[①-⑳]');

/// 该行是否为带数字编号的小项。
bool isNumberedLine(String line) {
  return _numberedLine.hasMatch(line) || _circledLine.hasMatch(line);
}

class _Line {
  final bool isItem;
  final int index; // 小项序号；标题为 -1。
  final String text;
  const _Line(this.isItem, this.index, this.text);
}

List<_Line> _parseLines(String text) {
  final List<String> raw = text.split('\n');
  final List<_Line> out = <_Line>[];
  int idx = 0;
  for (final String line in raw) {
    if (isNumberedLine(line)) {
      out.add(_Line(true, idx, line));
      idx++;
    } else {
      out.add(_Line(false, -1, line));
    }
  }
  return out;
}

/// 文本中所有小项的序号列表（即 0..n-1）。
List<int> parseItemIndices(String text) {
  return _parseLines(text)
      .where((_Line l) => l.isItem)
      .map((_Line l) => l.index)
      .toList();
}

/// 小项文本列表（保留原编号），用于 UI 展示。
List<String> itemTexts(String text) {
  return _parseLines(text)
      .where((_Line l) => l.isItem)
      .map((_Line l) => l.text)
      .toList();
}

/// 判断位置 [pos] 的标题是否应保留：其后（直到下一个标题或末尾）
/// 存在被选中的小项则为 true。
bool _headerKept(List<_Line> lines, int pos, Set<int> selected) {
  for (int j = pos + 1; j < lines.length; j++) {
    if (lines[j].isItem) {
      if (selected.contains(lines[j].index)) return true;
    } else {
      return false; // 遇到下一个标题，中间无选中项
    }
  }
  return false;
}

/// 按所选小项序号过滤文本。
/// [selected] 为 null 表示全选（原样返回）；为空集合表示「全不选」（返回空串）。
String filterSubItems(String text, Set<int>? selected) {
  if (selected == null) return text;
  final List<_Line> lines = _parseLines(text);
  // 该块文本本身没有带编号的小项（如家长版概括式段落）时，原样保留，
  // 避免被整段清空——否则家长版指导说明会因 selection 中无对应序号而被抹掉。
  // 必须与后端 OfflineTemplateService.filterSubItems 保持完全一致，
  // 否则屏幕预览与导出 PDF 的内容会对不上。
  final bool hasItemLines = lines.any((_Line l) => l.isItem);
  if (!hasItemLines) return text;
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < lines.length; i++) {
    final _Line l = lines[i];
    if (l.isItem) {
      if (selected.contains(l.index)) {
        if (sb.isNotEmpty) sb.write('\n');
        sb.write(l.text);
      }
    } else {
      if (_headerKept(lines, i, selected)) {
        if (sb.isNotEmpty) sb.write('\n');
        sb.write(l.text);
      }
    }
  }
  return sb.toString();
}

/// 将所选小项结构编码为可放入 URL 的 JSON 字符串。
String encodeSelectedItems(Map<String, Map<String, List<int>>> items) {
  return Uri.encodeQueryComponent(jsonEncode(items));
}

/// 从 URL 中的 JSON 字符串解码所选小项结构。
Map<String, Map<String, List<int>>>? decodeSelectedItems(String? param) {
  if (param == null || param.isEmpty) return null;
  try {
    final dynamic decoded = jsonDecode(Uri.decodeQueryComponent(param));
    if (decoded is! Map) return null;
    final Map<String, Map<String, List<int>>> out =
        <String, Map<String, List<int>>>{};
    decoded.forEach((dynamic k, dynamic v) {
      if (v is Map) {
        out[k.toString()] = <String, List<int>>{
          'rehabGoal': _toIntList(v['rehabGoal']),
          'guidance': _toIntList(v['guidance']),
        };
      }
    });
    return out;
  } catch (_) {
    return null;
  }
}

List<int> _toIntList(dynamic v) {
  if (v is! List) return <int>[];
  return v
      .whereType<num>()
      .map((num n) => n.toInt())
      .toList();
}
