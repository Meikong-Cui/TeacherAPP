import 'dart:convert';

/// 孤独症评估逐题作答结果（对应后端 autism_eval_item 表，多量表轮次模型）。
class AutismEvalItem {
  AutismEvalItem({
    this.id,
    required this.archiveId,
    this.formCode = 'STANDARD',
    this.roundId = 0,
    this.formItemId,
    this.evalSeq = 1,
    required this.areaKey,
    required this.itemCode,
    this.itemName = '',
    this.itemType = 'item',
    this.parentItemId,
    this.itemScope,
    this.refAge,
    this.rating,
    this.optionLabel,
    this.ageMinMonths,
    this.ageMaxMonths,
    this.note,
  });

  final int? id;
  final String archiveId;
  final String formCode; // STANDARD / OFFLINE / VB
  final int roundId; // 评估轮次 id
  final int? formItemId; // 关联 autism_eval_form_item.id（STANDARD 可为空）
  final int evalSeq; // 第几次评估
  final String areaKey; // 领域 / 维度
  final String itemCode; // 文档代号（如 1、★1、1A）
  final String itemName;
  final String itemType; // item / group
  final int? parentItemId; // 树形父题项
  final String? itemScope;
  final String? refAge;
  final String? rating; // P/E/F/X、A/M/S、0-3 分数、或 P/A；后端字段名 value
  final String? optionLabel; // 所选选项展示文本
  final int? ageMinMonths;
  final int? ageMaxMonths;
  final String? note;

  factory AutismEvalItem.fromJson(Map<String, dynamic> j) => AutismEvalItem(
        id: (j['id'] as int?) ?? int.tryParse(j['id']?.toString() ?? ''),
        archiveId: j['archiveId']?.toString() ?? '',
        formCode: _str(j['formCode'], 'STANDARD'),
        roundId: (j['roundId'] as int?) ??
            (int.tryParse(j['roundId']?.toString() ?? '0') ?? 0),
        formItemId: (j['formItemId'] as int?) ??
            int.tryParse(j['formItemId']?.toString() ?? ''),
        evalSeq: (j['evalSeq'] as int?) ??
            (int.tryParse(j['evalSeq']?.toString() ?? '1') ?? 1),
        areaKey: _str(j['areaKey'], ''),
        itemCode: _str(j['itemCode'], ''),
        itemName: _str(j['itemName']),
        itemType: _str(j['itemType'], 'item'),
        parentItemId: (j['parentItemId'] as int?) ??
            int.tryParse(j['parentItemId']?.toString() ?? ''),
        itemScope: j['itemScope']?.toString(),
        refAge: j['refAge']?.toString(),
        rating: j['value']?.toString(),
        optionLabel: j['optionLabel']?.toString(),
        ageMinMonths: (j['ageMinMonths'] as int?) ??
            int.tryParse(j['ageMinMonths']?.toString() ?? ''),
        ageMaxMonths: (j['ageMaxMonths'] as int?) ??
            int.tryParse(j['ageMaxMonths']?.toString() ?? ''),
        note: j['note']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'formCode': formCode,
        'roundId': roundId,
        if (formItemId != null) 'formItemId': formItemId,
        'evalSeq': evalSeq,
        'areaKey': areaKey,
        'itemCode': itemCode,
        if (itemName.isNotEmpty) 'itemName': itemName,
        'itemType': itemType,
        if (parentItemId != null) 'parentItemId': parentItemId,
        if (itemScope != null) 'itemScope': itemScope,
        if (refAge != null) 'refAge': refAge,
        if (rating != null) 'value': rating,
        if (optionLabel != null) 'optionLabel': optionLabel,
        if (ageMinMonths != null) 'ageMinMonths': ageMinMonths,
        if (ageMaxMonths != null) 'ageMaxMonths': ageMaxMonths,
        if (note != null) 'note': note,
      };
}

/// 评估选项（来自 autism_eval_form_item.options_json）。
class EvalOption {
  const EvalOption({required this.code, required this.label, this.score});
  final String code;
  final String label;
  final int? score;

  factory EvalOption.fromJson(Map<String, dynamic> j) => EvalOption(
        code: _str(j['code'], ''),
        label: _str(j['label']),
        score: (j['score'] as int?) ?? int.tryParse(j['score']?.toString() ?? ''),
      );
}

/// 量表定义（残联标准 / OFFLINE / VB …）。
class AutismEvalForm {
  const AutismEvalForm({
    this.id,
    required this.formCode,
    required this.formName,
    this.description,
    this.version,
    this.evalMethod,
    this.evalStandard,
    this.remark,
    this.status,
  });
  final int? id;
  final String formCode;
  final String formName;
  final String? description;
  final String? version;
  final String? evalMethod;
  final String? evalStandard;
  final String? remark;
  final int? status;

  factory AutismEvalForm.fromJson(Map<String, dynamic> j) => AutismEvalForm(
        id: (j['id'] as int?) ?? int.tryParse(j['id']?.toString() ?? ''),
        formCode: _str(j['formCode'], ''),
        formName: _str(j['formName']),
        description: j['description']?.toString(),
        version: j['version']?.toString(),
        evalMethod: j['evalMethod']?.toString(),
        evalStandard: j['evalStandard']?.toString(),
        remark: j['remark']?.toString(),
        status: (j['status'] as int?) ?? int.tryParse(j['status']?.toString() ?? ''),
      );
}

/// 量表题项定义（树形：group 总项目 / item 可作答题）。
class AutismEvalFormItem {
  const AutismEvalFormItem({
    this.id,
    required this.formCode,
    this.parentId,
    required this.itemCode,
    required this.itemName,
    this.itemType = 'item',
    this.areaKey,
    this.itemScope,
    this.ageMinMonths,
    this.ageMaxMonths,
    this.options = const <EvalOption>[],
    this.sortOrder,
    this.remark,
  });
  final int? id;
  final String formCode;
  final int? parentId;
  final String itemCode;
  final String itemName;
  final String itemType; // group / item
  final String? areaKey;
  final String? itemScope;
  final int? ageMinMonths;
  final int? ageMaxMonths;
  final List<EvalOption> options;
  final int? sortOrder;
  final String? remark;

  factory AutismEvalFormItem.fromJson(Map<String, dynamic> j) {
    List<EvalOption> opts = const <EvalOption>[];
    final dynamic raw = j['optionsJson'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          opts = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => EvalOption.fromJson(e))
              .toList();
        }
      } catch (_) {
        opts = const <EvalOption>[];
      }
    } else if (raw is List) {
      opts = raw
          .whereType<Map<String, dynamic>>()
          .map((e) => EvalOption.fromJson(e))
          .toList();
    }
    return AutismEvalFormItem(
      id: (j['id'] as int?) ?? int.tryParse(j['id']?.toString() ?? ''),
      formCode: _str(j['formCode'], ''),
      parentId:
          (j['parentId'] as int?) ?? int.tryParse(j['parentId']?.toString() ?? ''),
      itemCode: _str(j['itemCode'], ''),
      itemName: _str(j['itemName']),
      itemType: _str(j['itemType'], 'item'),
      areaKey: j['areaKey']?.toString(),
      itemScope: j['itemScope']?.toString(),
      ageMinMonths: (j['ageMinMonths'] as int?) ??
          int.tryParse(j['ageMinMonths']?.toString() ?? ''),
      ageMaxMonths: (j['ageMaxMonths'] as int?) ??
          int.tryParse(j['ageMaxMonths']?.toString() ?? ''),
      options: opts,
      sortOrder: (j['sortOrder'] as int?) ??
          int.tryParse(j['sortOrder']?.toString() ?? ''),
      remark: j['remark']?.toString(),
    );
  }
}

/// 评估轮次（一次评估 = 一个 round）。
class AutismEvalRound {
  const AutismEvalRound({
    this.id,
    required this.archiveId,
    required this.formCode,
    this.evalSeq,
    this.evalDate,
    this.evaluatorName,
    this.physiologicalAge,
    this.developmentalAge,
    this.status,
    this.remark,
  });
  final int? id;
  final String archiveId;
  final String formCode;
  final int? evalSeq;
  final DateTime? evalDate;
  final String? evaluatorName;
  final String? physiologicalAge;
  final String? developmentalAge;
  final int? status;
  final String? remark;

  factory AutismEvalRound.fromJson(Map<String, dynamic> j) => AutismEvalRound(
        id: (j['id'] as int?) ?? int.tryParse(j['id']?.toString() ?? ''),
        archiveId: j['archiveId']?.toString() ?? '',
        formCode: _str(j['formCode'], 'STANDARD'),
        evalSeq:
            (j['evalSeq'] as int?) ?? int.tryParse(j['evalSeq']?.toString() ?? ''),
        evalDate: _dtEval(j['evalDate']),
        evaluatorName: j['evaluatorName']?.toString(),
        physiologicalAge: j['physiologicalAge']?.toString(),
        developmentalAge: j['developmentalAge']?.toString(),
        status: (j['status'] as int?) ?? int.tryParse(j['status']?.toString() ?? ''),
        remark: j['remark']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'formCode': formCode,
        if (evalSeq != null) 'evalSeq': evalSeq,
        if (evalDate != null) 'evalDate': _fmtDate(evalDate!),
        if (evaluatorName != null) 'evaluatorName': evaluatorName,
        if (physiologicalAge != null) 'physiologicalAge': physiologicalAge,
        if (developmentalAge != null) 'developmentalAge': developmentalAge,
        if (status != null) 'status': status,
        if (remark != null) 'remark': remark,
      };
}

/// 轮次统计：按领域聚合（总项数 / 通过数 / 分数合计）。
class EvalAreaStat {
  const EvalAreaStat({
    required this.areaKey,
    required this.areaLabel,
    required this.total,
    required this.passCount,
    required this.failCount,
    required this.sumScore,
    required this.avgScore,
  });
  final String areaKey;
  final String areaLabel;
  final int total;
  final int passCount;
  final int failCount;
  final int sumScore;
  final double avgScore;

  factory EvalAreaStat.fromJson(Map<String, dynamic> j) => EvalAreaStat(
        areaKey: _str(j['areaKey'], ''),
        areaLabel: _str(j['areaLabel'], _str(j['areaKey'], '')),
        total: _int(j['total']),
        passCount: _int(j['passCount']),
        failCount: _int(j['failCount']),
        sumScore: _int(j['sumScore']),
        avgScore: _dbl(j['avgScore']),
      );
}

/// 轮次统计聚合（后端 /rounds/{roundId}/stats 返回）。
class EvalRoundStats {
  const EvalRoundStats({
    required this.roundId,
    required this.formCode,
    required this.itemCount,
    required this.areas,
    required this.items,
  });
  final int roundId;
  final String formCode;
  final int itemCount;
  final List<EvalAreaStat> areas;
  final List<AutismEvalItem> items;

  factory EvalRoundStats.fromJson(Map<String, dynamic> j) => EvalRoundStats(
        roundId: (j['roundId'] as int?) ??
            int.tryParse(j['roundId']?.toString() ?? '0') ??
            0,
        formCode: _str(j['formCode'], ''),
        itemCount: _int(j['itemCount']),
        areas: _list(j['areas'], EvalAreaStat.fromJson),
        items: _list(j['items'], AutismEvalItem.fromJson),
      );
}

DateTime? _dtEval(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());
String _fmtDate(DateTime d) => d.toIso8601String().split('T').first;

String _str(dynamic v, [String d = '']) => v == null ? d : v.toString();

/// 8 大领域剖面图单项（某次评估下每域的 P 数 / 总项数）。
class EvalAreaProfile {
  EvalAreaProfile({
    required this.areaKey,
    required this.areaLabel,
    required this.total,
    required this.pCount,
    required this.pRatio,
  });
  final String areaKey;
  final String areaLabel;
  final int total;
  final int pCount;
  final double pRatio;

  factory EvalAreaProfile.fromJson(Map<String, dynamic> j) => EvalAreaProfile(
        areaKey: _str(j['areaKey'], ''),
        areaLabel: _str(j['areaLabel'], _str(j['areaKey'], '')),
        total: _int(j['total']),
        pCount: _int(j['pCount']),
        pRatio: _dbl(j['pRatio']),
      );
}

/// 情绪与行为 6 子维度剖面单项。
class EvalEmotionProfile {
  EvalEmotionProfile({
    required this.dimKey,
    required this.dimLabel,
    required this.total,
    required this.pCount,
    required this.pRatio,
  });
  final String dimKey;
  final String dimLabel;
  final int total;
  final int pCount;
  final double pRatio;

  factory EvalEmotionProfile.fromJson(Map<String, dynamic> j) => EvalEmotionProfile(
        dimKey: _str(j['dimKey'], ''),
        dimLabel: _str(j['dimLabel'], _str(j['dimKey'], '')),
        total: _int(j['total']),
        pCount: _int(j['pCount']),
        pRatio: _dbl(j['pRatio']),
      );
}

/// 折线图单点（某题在某评估次数下的值 + 累计 P 数）。
class EvalSeriesPoint {
  EvalSeriesPoint({
    required this.seq,
    this.value,
    required this.cumulative,
  });
  final int seq;
  final String? value;
  final int cumulative;

  factory EvalSeriesPoint.fromJson(Map<String, dynamic> j) => EvalSeriesPoint(
        seq: _int(j['seq']),
        value: j['value']?.toString(),
        cumulative: _int(j['cumulative']),
      );
}

/// 每题的折线序列。
class EvalItemSeries {
  EvalItemSeries({
    required this.areaKey,
    required this.itemCode,
    required this.itemName,
    required this.points,
  });
  final String areaKey;
  final String itemCode;
  final String itemName;
  final List<EvalSeriesPoint> points;

  factory EvalItemSeries.fromJson(Map<String, dynamic> j) => EvalItemSeries(
        areaKey: _str(j['areaKey'], ''),
        itemCode: _str(j['itemCode'], ''),
        itemName: _str(j['itemName']),
        points: (j['points'] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((e) => EvalSeriesPoint.fromJson(e))
            .toList(),
      );
}

/// 某领域的折线序列（每个评估次数的 P 数）。
class EvalAreaSeries {
  EvalAreaSeries({
    required this.areaKey,
    required this.areaLabel,
    required this.points,
  });
  final String areaKey;
  final String areaLabel;
  final List<EvalAreaPoint> points;

  factory EvalAreaSeries.fromJson(Map<String, dynamic> j) => EvalAreaSeries(
        areaKey: _str(j['areaKey'], ''),
        areaLabel: _str(j['areaLabel'], _str(j['areaKey'], '')),
        points: (j['points'] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((e) => EvalAreaPoint.fromJson(e))
            .toList(),
      );
}

class EvalAreaPoint {
  EvalAreaPoint({required this.seq, required this.pCount});
  final int seq;
  final int pCount;

  factory EvalAreaPoint.fromJson(Map<String, dynamic> j) => EvalAreaPoint(
        seq: _int(j['seq']),
        pCount: _int(j['pCount']),
      );
}

/// 评估统计聚合（后端 getEvalStats 返回）。
class AutismEvalStats {
  AutismEvalStats({
    required this.items,
    required this.profile8,
    required this.profileEmotion,
    required this.series,
    required this.areaSeries,
    required this.evalSeqs,
    required this.maxPSum,
  });

  final List<EvalItemSeries> items;
  final List<EvalAreaProfile> profile8;
  final List<EvalEmotionProfile> profileEmotion;
  final List<EvalItemSeries> series;
  final List<EvalAreaSeries> areaSeries;
  final List<int> evalSeqs;
  final int maxPSum;

  factory AutismEvalStats.fromJson(Map<String, dynamic> j) => AutismEvalStats(
        items: _list(j['items'], EvalItemSeries.fromJson),
        profile8: _list(j['profile8'], EvalAreaProfile.fromJson),
        profileEmotion: _list(j['profileEmotion'], EvalEmotionProfile.fromJson),
        series: _list(j['series'], EvalItemSeries.fromJson),
        areaSeries: _list(j['areaSeries'], EvalAreaSeries.fromJson),
        evalSeqs: (j['evalSeqs'] as List? ?? <dynamic>[])
            .map((e) => _int(e))
            .where((e) => e > 0)
            .toList(),
        maxPSum: _int(j['maxPSum']),
      );

  /// 全部题目在某评估次数下的 P 总数（用于总趋势线）。
  int totalPAt(int seq) {
    int s = 0;
    for (final a in areaSeries) {
      for (final p in a.points) {
        if (p.seq == seq) s += p.pCount;
      }
    }
    return s;
  }

  /// 全部题目在所有评估次数下的 P 总数序列。
  List<int> totalPSeries() =>
      evalSeqs.map((s) => totalPAt(s)).toList();
}

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) {
  if (v is! List) return <T>[];
  return v.whereType<Map<String, dynamic>>().map(f).toList();
}

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

double _dbl(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
