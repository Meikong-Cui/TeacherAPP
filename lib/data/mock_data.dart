import 'package:teacher_app/data/models/assessment.dart';
import 'package:teacher_app/data/models/child.dart';
import 'package:teacher_app/data/models/guidance.dart';
import 'package:teacher_app/data/models/message.dart';
import 'package:teacher_app/data/models/todo.dart';
import 'package:teacher_app/data/models/user.dart';
export 'package:teacher_app/data/models/assessment.dart';
export 'package:teacher_app/data/models/child.dart';
export 'package:teacher_app/data/models/guidance.dart';
export 'package:teacher_app/data/models/message.dart';
export 'package:teacher_app/data/models/todo.dart';
export 'package:teacher_app/data/models/user.dart';
export 'package:teacher_app/data/models/campus.dart';
export 'package:teacher_app/data/models/reimbursement.dart';

/// 演示数据层（移植自前端原型 mock-data.js）。
/// 真实环境接入后，由后端 REST API 替换此处。
class MockData {
  const MockData._();

  static const TeacherUser currentUser = TeacherUser.demo;

  static const List<Child> children = <Child>[
    Child(
      id: 'DEMO-001',
      name: '陈予安',
      gender: '男',
      birth: '2019-12-10',
      ageText: '6岁7个月',
      group: '感知认知组',
      status: '在训',
      guardian: '陈女士',
      phone: '138****0000',
      primaryTeacher: '林老师',
      iepProgress: 64,
      weeklyTrain: 3,
      nextDate: '07-16',
      iep: Iep(
        title: '2026 夏季 IEP',
        start: '2026-05-01',
        end: '2026-08-31',
        status: '执行中',
        completed: 2,
        total: 5,
        goals: <IepGoal>[
          IepGoal(
            domain: '语言沟通',
            status: '进行中',
            title: '使用完整短句表达需求',
            desc: '在图片或实物提示下，连续 3 次使用 5 字以上短句表达需求。',
            owner: '林老师',
            deadline: '2026-07-31',
            progress: 64,
          ),
          IepGoal(
            domain: '社交互动',
            status: '进行中',
            title: '主动发起同伴互动',
            desc: '在自然情境下主动发起互动，每节课不少于 3 次。',
            owner: '林老师',
            deadline: '2026-07-31',
            progress: 40,
          ),
          IepGoal(
            domain: '生活自理',
            status: '3天后截止',
            title: '独立整理训练材料',
            desc: '训练结束后按分类独立归位，连续 5 次达成。',
            owner: '林老师',
            deadline: '2026-07-17',
            progress: 82,
            warning: true,
          ),
        ],
      ),
      timeline: <ChildTimelineItem>[
        ChildTimelineItem(
          type: '训练',
          title: '完成个训记录',
          desc: '语言沟通图片训练 · 完成度 70%',
          time: '今天 10:36',
          actor: '林老师',
        ),
        ChildTimelineItem(
          type: '评估',
          title: '评估草稿已保存',
          desc: 'S-S 语言发育迟缓检查 · 18/32 项',
          time: '昨天 16:20',
          actor: '王评估师',
        ),
        ChildTimelineItem(
          type: '审核',
          title: 'IEP 周期审核通过',
          desc: '主管意见：目标清晰，可按计划执行',
          time: '5月2日 09:12',
          actor: '刘主管',
        ),
      ],
    ),
    Child(
      id: 'DEMO-002',
      name: '周子墨',
      gender: '男',
      birth: '2021-05-18',
      ageText: '5岁2个月',
      group: '社交沟通组',
      status: '暂停',
      guardian: '周先生',
      phone: '139****1111',
      primaryTeacher: '林老师',
      iepProgress: 82,
      weeklyTrain: 2,
      nextDate: '07-17',
      timeline: <ChildTimelineItem>[],
    ),
    Child(
      id: 'DEMO-003',
      name: '林芷晴',
      gender: '女',
      birth: '2021-10-03',
      ageText: '4岁9个月',
      group: '语言训练组',
      status: '在训',
      guardian: '林女士',
      phone: '137****2222',
      primaryTeacher: '王老师',
      iepProgress: 45,
      weeklyTrain: 4,
      nextDate: '07-22',
      timeline: <ChildTimelineItem>[],
    ),
    Child(
      id: 'DEMO-004',
      name: '张安',
      gender: '男',
      birth: '2020-08-21',
      ageText: '5岁11个月',
      group: '感知认知组',
      status: '在训',
      guardian: '张女士',
      phone: '136****3333',
      primaryTeacher: '林老师',
      iepProgress: 71,
      weeklyTrain: 3,
      nextDate: '07-18',
      timeline: <ChildTimelineItem>[],
    ),
  ];

  static const Todos todos = Todos(
    total: 7,
    items: <TodoItem>[
      TodoItem(
        type: 'assess',
        title: '待完成评估',
        count: 2,
        desc: '陈予安 · S-S 语言发育迟缓检查',
        icon: 'orange',
      ),
      TodoItem(
        type: 'record',
        title: '训练记录待补',
        count: 2,
        desc: '昨天的个训记录尚未完成',
        icon: 'blue',
      ),
      TodoItem(
        type: 'goal',
        title: '目标临近截止',
        count: 1,
        desc: '周子墨 · 社交沟通 · 还有 3 天',
        icon: 'rose',
      ),
    ],
  );

  static const List<Assessment> assessments = <Assessment>[
    Assessment(
      id: 'A-20260714-001',
      name: 'S-S 语言发育迟缓检查',
      status: '填写中',
      child: '陈予安',
      date: '2026.07.14',
      version: 'V2.1',
      progress: 18,
      total: 32,
      autoSave: '10:32',
      chapter: '第 2 章：语言理解',
      questions: <AssessmentQuestion>[
        AssessmentQuestion(
          id: 19,
          title: '儿童能否理解并执行“把杯子放在桌子上”这一两步指令？',
          options: <String>['不能完成', '提示后能够完成', '可独立完成'],
        ),
        AssessmentQuestion(
          id: 20,
          title: '儿童能否根据用途指出常见物品？',
          options: <String>['不能完成', '提示后能够完成', '可独立完成'],
        ),
      ],
    ),
    Assessment(
      id: 'A-20260715-002',
      name: '儿童感觉统合能力发展评定',
      status: '未开始',
      child: '林芷晴',
      date: '2026.07.15',
      version: 'V1.3',
      progress: 0,
      total: 48,
      autoSave: null,
      chapter: '',
      questions: <AssessmentQuestion>[],
    ),
  ];

  static const List<AppMessage> messages = <AppMessage>[
    AppMessage(
      type: 'system',
      title: 'IEP 审核已通过',
      desc: '陈予安的“2026 夏季 IEP”已由刘主管审核通过，可进入训练执行。',
      time: '今天 09:12',
      icon: 'green',
    ),
    AppMessage(
      type: 'todo',
      title: '训练记录待补充',
      desc: '你昨天有 2 条训练记录尚未填写儿童个别表现。',
      time: '今天 08:30',
      icon: 'blue',
    ),
    AppMessage(
      type: 'warning',
      title: '目标临近截止',
      desc: '周子墨的“主动发起同伴互动”目标将在 3 天后截止。',
      time: '昨天 16:40',
      icon: 'amber',
    ),
    AppMessage(
      type: 'system',
      title: '评估草稿已恢复',
      desc: 'S-S 语言发育迟缓检查已恢复至最近一次成功保存的 18/32 项。',
      time: '昨天 10:20',
      icon: 'green',
    ),
  ];

  static const Guidance guidance = Guidance(
    title: '在家练习“主动表达需求”',
    relation: '陈予安 · 2026 夏季 IEP · 语言沟通领域',
    target: '帮助孩子在吃饭、喝水和玩玩具时，主动用完整短句表达自己的需要。',
    steps: <String>[
      '把孩子喜欢的物品放在看得到但拿不到的位置。',
      '等待孩子主动表达，必要时先示范“我想要积木”。',
      '孩子表达后立即回应，并给予具体鼓励。',
    ],
    notice: '每天练习 2—3 次，每次 5 分钟即可。不要反复追问，也不要替孩子直接说出答案。',
  );
}

// 注意：所有 Riverpod Provider（currentUserProvider / childrenProvider / 等）
// 已统一迁移到 data/providers.dart，各页面请通过 provider 访问数据，
// 不要直接引用本类的静态字段（便于后续切换真实数据源）。

