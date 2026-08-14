/// 孤独症评估题目逐题评分条目（对应后端 autism_eval_item 表）。
class AutismEvalItem {
  AutismEvalItem({
    this.id,
    required this.archiveId,
    required this.source,
    required this.sourceId,
    required this.evalSeq,
    required this.areaKey,
    required this.itemCode,
    this.itemName = '',
    this.itemScope,
    this.refAge,
    this.value,
    this.note,
  });

  final int? id;
  final String archiveId;
  final String source; // FIRST / CONT
  final int sourceId; // 关联评估记录 id（无则为 0）
  final int evalSeq; // 1/2/3 → 第一次/第二次/第三次
  final String areaKey; // perception/gross_motor/.../emotion
  final String itemCode; // 文档代号（如 1、★1）
  final String itemName;
  final String? itemScope;
  final String? refAge;
  final String? value; // P/E/F/X 或 A/M/S；null 表示未评/清空
  final String? note;

  factory AutismEvalItem.fromJson(Map<String, dynamic> j) => AutismEvalItem(
        id: (j['id'] as int?) ?? (int.tryParse(j['id']?.toString() ?? '')),
        archiveId: j['archiveId']?.toString() ?? '',
        source: _str(j['source'], 'FIRST'),
        sourceId: (j['sourceId'] as int?) ??
            (int.tryParse(j['sourceId']?.toString() ?? '0') ?? 0),
        evalSeq: (j['evalSeq'] as int?) ??
            (int.tryParse(j['evalSeq']?.toString() ?? '1') ?? 1),
        areaKey: _str(j['areaKey'], ''),
        itemCode: _str(j['itemCode'], ''),
        itemName: _str(j['itemName']),
        itemScope: j['itemScope']?.toString(),
        refAge: j['refAge']?.toString(),
        value: j['value']?.toString(),
        note: j['note']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'source': source,
        'sourceId': sourceId,
        'evalSeq': evalSeq,
        'areaKey': areaKey,
        'itemCode': itemCode,
        if (itemName.isNotEmpty) 'itemName': itemName,
        if (itemScope != null) 'itemScope': itemScope,
        if (refAge != null) 'refAge': refAge,
        if (value != null) 'value': value,
        if (note != null) 'note': note,
      };
}

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
