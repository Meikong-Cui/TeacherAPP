// 持续评估表（1.1.2）——按纸表目录渲染的全量表单（App 端）。
//
// 目录 contEvalCatalog 由 tools/cont_eval_measure 从官方纸表 cont_eval.pdf
// （整版位图，无文字层）逐框像素检测生成，是「纸表结构」的唯一真相源：
//   · 每个 □ 复选框 = 一条 sym 条目
//   · 每个矩阵空格（声源辨识 6 列 / 林氏六音 6 音 × 4 距离）= 一条 sym 条目
//   · 少数纯文字栏（儿歌童谣、家长进步…）= fields 条目
// 取值统一为四档符号 1 开始 / 2 不稳 / 3 稳定 / 4 表达（与网页端、导出 PDF 同源）。
//
// 域名为「实体字段名」（如 hearingData），与后端 RehabContEval 的列一一对应，
// 保存时按域整体 jsonEncode 提交。
import 'package:flutter/material.dart';

import '../../data/cont_eval_catalog.dart';
import 'hearing_symbol.dart';

/// 单个符号条目：左标签 + 右四档符号选择器。
class _SymRow extends StatelessWidget {
  const _SymRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13.5, height: 1.25)),
            ),
            const SizedBox(width: 6),
            SymbolPicker(selected: value, onChanged: onChanged, size: 24),
          ],
        ),
      );
}

/// 矩阵区块（声源辨识 / 林氏六音）：行 = 距离，列 = 方向或音素。
class _Matrix extends StatelessWidget {
  const _Matrix({required this.section, required this.maps, required this.onChanged});
  final ContSection section;
  final Map<String, Map<String, dynamic>> maps;
  final VoidCallback onChanged;

  void _set(String domain, String key, int? v) {
    final Map<String, dynamic> m = maps[domain]!;
    if (v == null) {
      m.remove(key);
    } else {
      m[key] = v;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final String dom = section.domain ?? '';
    final List<String> colLabels = section.colLabels ?? const <String>[];
    final List<String> rowLabels = section.rowLabels ?? const <String>[];
    final List<List<ContItem>> cells = section.cells ?? const <List<ContItem>>[];
    final Color line = Colors.grey.shade300;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const SizedBox(width: 46),
            for (final String c in colLabels)
              SizedBox(
                width: 112,
                child: Center(
                  child: Text(c,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          for (int r = 0; r < cells.length; r++) ...<Widget>[
            Row(children: <Widget>[
              SizedBox(
                width: 46,
                child: Text(r < rowLabels.length ? rowLabels[r] : '',
                    style: const TextStyle(fontSize: 12)),
              ),
              for (final ContItem cell in cells[r])
                SizedBox(
                  width: 112,
                  child: Center(
                    child: SymbolPicker(
                      size: 20,
                      selected: HearingSymbol.indexFromValue(maps[dom]?[cell.key]),
                      onChanged: (int? v) => _set(dom, cell.key, v),
                    ),
                  ),
                ),
            ]),
            Container(height: 1, color: line),
          ],
        ],
      ),
    );
  }
}

/// 目录里的一个区块。
class _Section extends StatelessWidget {
  const _Section({required this.section, required this.maps, required this.onChanged});
  final ContSection section;
  final Map<String, Map<String, dynamic>> maps;
  final VoidCallback onChanged;

  void _set(String domain, String key, int? v) {
    final Map<String, dynamic> m = maps[domain]!;
    if (v == null) {
      m.remove(key);
    } else {
      m[key] = v;
    }
    onChanged();
  }

  void _setText(String domain, String key, String v) {
    maps[domain]![key] = v;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final List<Widget> body = <Widget>[];

    if (section.layout == ContLayout.matrix) {
      body.add(_Matrix(section: section, maps: maps, onChanged: onChanged));
    } else if (section.layout == ContLayout.fields) {
      final String dom = section.domain ?? '';
      for (final ContItem f in section.fields ?? const <ContItem>[]) {
        body.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            initialValue: (maps[dom]?[f.key] ?? '').toString(),
            maxLines: f.kind == ContKind.text ? 2 : 1,
            minLines: 1,
            keyboardType: f.kind == ContKind.num
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: f.kind == ContKind.date ? '${f.label}（YYYY-MM-DD）' : f.label,
              labelStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primary)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (String v) => _setText(dom, f.key, v),
          ),
        ));
      }
    } else {
      // grid / rows：逐条四档符号。rows（长标签）整行独占，grid 一列一项。
      final List<List<Object>> rows = <List<Object>>[];
      if (section.rows != null && section.rows!.isNotEmpty) {
        for (final ContRow r in section.rows!) {
          for (final ContItem it in r.items) {
            rows.add(<Object>[r.domain ?? section.domain ?? '', it]);
          }
        }
      } else {
        for (final ContItem it in section.items ?? const <ContItem>[]) {
          rows.add(<Object>[section.domain ?? '', it]);
        }
      }
      for (final List<Object> pair in rows) {
        final String dom = pair[0] as String;
        final ContItem it = pair[1] as ContItem;
        body.add(_SymRow(
          label: it.label,
          value: HearingSymbol.indexFromValue(maps[dom]?[it.key]),
          onChanged: (int? v) => _set(dom, it.key, v),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
          child: Row(children: <Widget>[
            Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                    color: primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Expanded(
              child: Text(section.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5, color: primary)),
            ),
          ]),
        ),
        if (section.note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(section.note!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        Padding(padding: const EdgeInsets.only(left: 9), child: Column(children: body)),
      ],
    );
  }
}

/// 纸表一页的全部区块（域为 'contEval' 的区块由页面顶部固定表单承担，这里跳过）。
class ContEvalCatalogPageView extends StatelessWidget {
  const ContEvalCatalogPageView({
    required this.page,
    required this.maps,
    required this.onChanged,
    super.key,
  });

  final ContPage page;
  final Map<String, Map<String, dynamic>> maps;
  final VoidCallback onChanged;

  static const String topLevelDomain = 'contEval';

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: <Widget>[
        Text('第 ${page.page + 1} / 7 页 · ${page.title}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: primary)),
        ...page.sections
            .where((ContSection s) => s.domain != topLevelDomain)
            .map((ContSection s) => _Section(
                  section: s,
                  maps: maps,
                  onChanged: onChanged,
                )),
      ],
    );
  }
}
