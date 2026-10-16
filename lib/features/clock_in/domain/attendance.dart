import 'package:teacher_app/data/models/clock_record.dart';

/// 后台下发的「今日考勤」视图（GET /api/oa/record/attendance-today）。
///
/// 存在意义：打卡页必须在打卡**之前**知道「我今天该几点上班 / 现在算不算迟到 /
/// 今天打过上班卡没有」。这三件事的真相在后台（员工覆盖 > 校区默认 > 全局兜底），
/// 客户端写死 9:00 / 18:00 会在校区改时间后集体误判迟到 —— 所以一律以后台为准，
/// 本地只做「拿不到后台数据」时的兜底展示。
class AttendanceToday {
  const AttendanceToday({
    required this.date,
    required this.start,
    required this.end,
    this.employee,
    this.remindBeforeMinutes,
    this.onTime,
    this.offTime,
    this.statusLabel,
    this.serverEpochMillis,
  });

  /// 后台认为的「今天」（yyyy-MM-dd）。
  final String date;

  /// 生效上班时间 'HH:mm'。
  final String start;

  /// 生效下班时间 'HH:mm'。
  final String end;

  final String? employee;
  final int? remindBeforeMinutes;

  /// 当天已打卡的上班时间（合并后取最早）；null 表示还没打上班卡。
  final String? onTime;

  /// 当天已打卡的下班时间（合并后取最晚）；null 表示还没打下班卡。
  final String? offTime;

  final String? statusLabel;

  /// 后台当前时刻（毫秒时间戳）。用于校准手机时钟：系统时间被改过会让「迟到判定」
  /// 与「打卡时刻」同时失真，App 以它与本地时间的差值做偏移校正。
  final int? serverEpochMillis;

  /// 与本地时钟的偏差（本地 + 该值 = 后台时间）。拿不到后台时间时为 0。
  Duration get serverOffset => serverEpochMillis == null
      ? Duration.zero
      : Duration(
          milliseconds: serverEpochMillis! -
              DateTime.now().millisecondsSinceEpoch,
        );

  /// 后台口径的「现在」。
  DateTime get now => DateTime.now().add(serverOffset);

  bool get hasCheckedIn => onTime != null && onTime!.isNotEmpty;
  bool get hasCheckedOut => offTime != null && offTime!.isNotEmpty;

  /// [t] 是否晚于生效上班时间（'HH:mm:ss' 与 'HH:mm' 补齐后比较，字典序即时间序）。
  bool isLateAt(DateTime t) => _laterThan(t, start);

  /// [t] 是否早于生效下班时间（下班早退判定）。
  bool isEarlyAt(DateTime t) => !_laterThan(t, end);

  static bool _laterThan(DateTime t, String limit) {
    final String now = _hhmmss(t);
    final String lim = limit.trim().length == 5 ? '$limit:00' : limit.trim();
    return now.compareTo(lim) > 0;
  }

  static String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  factory AttendanceToday.fromJson(Map<String, dynamic> json) {
    String? s(String k) => json[k]?.toString();

    return AttendanceToday(
      date: s('date') ?? '',
      start: s('start') ?? '09:00',
      end: s('end') ?? '18:00',
      employee: s('employee'),
      remindBeforeMinutes: json['remindBeforeMinutes'] is num
          ? (json['remindBeforeMinutes'] as num).toInt()
          : int.tryParse(s('remindBeforeMinutes') ?? ''),
      // 空串按「没打过」处理：后台 JSON 里缺字段与空串是两种写法，语义相同。
      onTime: _blankToNull(s('onTime')),
      offTime: _blankToNull(s('offTime')),
      statusLabel: _blankToNull(s('statusLabel')),
      serverEpochMillis: json['serverEpochMillis'] is num
          ? (json['serverEpochMillis'] as num).toInt()
          : int.tryParse(s('serverEpochMillis') ?? ''),
    );
  }

  static String? _blankToNull(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }
}

/// 一次打卡的**结果**（后台合并后的当天状态）。
///
/// 打卡页靠它弹「结果确认卡片」：告诉老师这次记的是上班还是下班、几点、状态如何，
/// 而不用再回调一次列表接口去猜。
class ClockSubmitResult {
  const ClockSubmitResult({
    required this.type,
    required this.time,
    this.id,
    this.onTime,
    this.offTime,
    this.onTimeSec,
    this.offTimeSec,
    this.statusLabel,
    this.late = false,
    this.synced = true,
  });

  final ClockType type;

  /// 本次打卡时刻（本地口径，用于卡片展示到秒）。
  final DateTime time;

  /// 后台记录 id；离线留存未同步时为 null。
  final int? id;

  final String? onTime;
  final String? offTime;

  /// 秒级时刻（后台留痕，'HH:mm:ss'）。
  final String? onTimeSec;
  final String? offTimeSec;

  /// 后台重算的状态：正常 / 迟到 / 早退。离线时为 null（未重算）。
  final String? statusLabel;

  /// 后台判定本次上班迟到。
  final bool late;

  /// 是否已同步到后台。false = 已打卡但落本地待同步队列。
  final bool synced;

  /// 卡片上展示的时刻（到秒）。
  String get timeText => '${t(time.hour)}:${t(time.minute)}:${t(time.second)}';

  String t(int n) => n.toString().padLeft(2, '0');

  /// 卡片副标题：优先用后台秒级值，离线时用本地时刻。
  String get displayTime => (type == ClockType.checkIn
          ? (onTimeSec ?? onTime)
          : (offTimeSec ?? offTime)) ??
      timeText;

  factory ClockSubmitResult.fromJson(ClockType type, Map<String, dynamic> json) {
    String? s(String k) {
      final Object? v = json[k];
      if (v == null) return null;
      final String str = v.toString().trim();
      return str.isEmpty ? null : str;
    }

    return ClockSubmitResult(
      type: type,
      // 后台不回「打卡时刻」的绝对时间，卡片按本地时刻展示即可（两者同一个瞬间）。
      time: DateTime.now(),
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      onTime: s('onTime'),
      offTime: s('offTime'),
      onTimeSec: s('onTimeSec'),
      offTimeSec: s('offTimeSec'),
      statusLabel: s('statusLabel'),
      late: json['late'] == true,
      synced: true,
    );
  }
}
