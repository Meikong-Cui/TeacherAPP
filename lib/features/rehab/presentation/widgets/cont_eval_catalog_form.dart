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

/// 把存量日期文本收敛成 `YYYY-MM-DD`；认不出来返回 null。
///
/// **这段规则必须与网页端 `canonicalDate`（oa-admin-web/src/components/rehab/
/// ContEvalCatalogForm.tsx）逐字对应**，否则同一份数据在网页能规范化、在 App 却被判非法，
/// 老师会以为其中一端坏了。Dart 的 `DateTime.tryParse` 只认 ISO（`2026/3/2` 会返回 null），
/// 所以这里显式补上斜杠写法，并且只认这一种；不要改成更宽松的变体。
/// 回读校验 y/m/d 是为了挡掉 `2026-02-31` 这种被 DateTime 自动进位的假日期。
///
/// 公开（不带下划线）是为了让 test/cont_eval_date_field_test.dart 能直接覆盖它。
String? canonicalContEvalDate(String? raw) {
  final String t = (raw ?? '').trim();
  if (t.isEmpty) return null;
  final RegExpMatch? m =
      RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T].*)?$').firstMatch(t);
  if (m == null) return null;
  final int? y = int.tryParse(m.group(1)!);
  final int? mo = int.tryParse(m.group(2)!);
  final int? dd = int.tryParse(m.group(3)!);
  if (y == null || mo == null || dd == null) return null;
  if (mo < 1 || mo > 12 || dd < 1 || dd > 31) return null;
  final DateTime d = DateTime(y, mo, dd);
  if (d.year != y || d.month != mo || d.day != dd) return null;
  return '${y.toString().padLeft(4, '0')}-'
      '${mo.toString().padLeft(2, '0')}-'
      '${dd.toString().padLeft(2, '0')}';
}

/// 日期条目：点击弹系统日期选择器，写回始终是 `YYYY-MM-DD` 字符串。
///
/// 不让老师手打的原因与网页端一致 —— 纸表上的「评估时间」会被导出端**原样叠印**
/// 到 PDF 上，手打就没有任何格式约束（实测出现过 `2026.3.2`、`2026年3月2日`
/// 这类值，导出后直接印在纸上）。文本框设为 readOnly，从根上杜绝非法输入。
///
/// 存**字符串**而不是 DateTime 是刻意为之：后端列与网页端都按文本读写这份 JSON，
/// 换成 DateTime 再 jsonEncode 会变成 ISO8601 带时区，两边都读不出来。
///
/// 存量数据两种情况都不静默：
///   · 能认出来但不是标准写法（`2026/3/2`）→ 打开时就改成 `YYYY-MM-DD` 并在下方留一行说明
///   · 认不出来（`待定`）→ 字段留空并提示原值，不会被无声清掉
class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  /// 本次打开时被自动规范过的原值（仅用于显示一行说明）。
  String _normalizedFrom = '';

  /// 已存的规范日期字符串；空串或认不出来返回 null（此时选择器从「今天」起跳）。
  String? get _canonical => canonicalContEvalDate(widget.value);

  bool get _isInvalid =>
      widget.value.trim().isNotEmpty && canonicalContEvalDate(widget.value) == null;

  @override
  void initState() {
    super.initState();
    final String? c = _canonical;
    if (c == null || c == widget.value.trim()) return;
    _normalizedFrom = widget.value.trim();
    _c.text = c;
    // 规范化要写回上层数据源，会触发父级 setState —— 不能在 build 期间做，
    // 所以推迟到当前帧结束。即便回调没跑，本地 _c 已是规范值，界面不会自相矛盾。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(c);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final DateTime now = DateTime.now();
    final String? cur = _canonical;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: cur == null ? now : (DateTime.tryParse(cur) ?? now),
      // 康复档案的合理区间：孩子不可能 30 年前做评估，也不会是 5 年后。
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: widget.label,
    );
    if (picked == null) return;
    final String v = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      _c.text = v;
      _normalizedFrom = '';
    });
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return TextFormField(
      controller: _c,
      readOnly: true,
      onTap: _pick,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 13),
        hintText: '点击选择日期',
        prefixIcon: const Icon(Icons.event_outlined, size: 18),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primary)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        errorText: _isInvalid ? '原值「${widget.value}」不是有效日期，请重新选择' : null,
        helperText: _normalizedFrom.isEmpty
            ? null
            : '原值「$_normalizedFrom」已按标准格式记为 ${_c.text}',
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        helperMaxLines: 2,
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
          child: f.kind == ContKind.date
              // 日期不再让老师手打，见 _DateField 的注释。
              ? _DateField(
                  label: f.label,
                  value: (maps[dom]?[f.key] ?? '').toString(),
                  onChanged: (String v) => _setText(dom, f.key, v),
                )
              : TextFormField(
                  initialValue: (maps[dom]?[f.key] ?? '').toString(),
                  maxLines: f.kind == ContKind.text ? 2 : 1,
                  minLines: 1,
                  keyboardType: f.kind == ContKind.num
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: f.label,
                    labelStyle: const TextStyle(fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: primary)),
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
