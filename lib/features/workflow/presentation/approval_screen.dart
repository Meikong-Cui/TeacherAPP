import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// 统一审批入口页。
///
/// 办公页只放一个「审批」入口，进来后按**审批类型分卡片**：
/// 请假 / 补卡 / 报销 / 用章 …… 每张卡显示待我审批的数量。
///
/// 数据来源：后端 `GET /api/workflow/instances/todo` 已按当前节点的审批人过滤，
/// 所以财务只能看到财务级的单、园长/管理员只看到流转到自己这级的单，
/// 教师角色在后端就拿不到任何待办（前端入口也已按角色隐藏）。
class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final WorkflowRepository _repo = WorkflowRepository();
  bool _loading = true;
  String? _error;
  List<WorkflowInstance> _todo = <WorkflowInstance>[];

  /// 固定展示的审批类型（即使为 0 也显示，保持入口稳定）；
  /// 其它未预设的类型只要有待办也会自动出现。
  static const List<_ApprovalKind> _kinds = <_ApprovalKind>[
    _ApprovalKind(name: '请假审批', label: '请假', icon: Icons.event_busy_outlined,
        gradient: AppGradients.rose),
    _ApprovalKind(name: '补卡申请', label: '补卡', icon: Icons.fact_check_outlined,
        gradient: AppGradients.amber),
    _ApprovalKind(name: '费用报销', label: '报销', icon: Icons.receipt_long_outlined,
        gradient: AppGradients.teal),
    _ApprovalKind(name: '用章申请', label: '用章', icon: Icons.gpp_good_outlined,
        gradient: AppGradients.sky),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _todo = await _repo.listTodo();
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  int _countOf(String templateName) =>
      _todo.where((WorkflowInstance i) => i.templateName == templateName).length;

  /// 预设类型 + 实际有待办但没预设的类型。
  List<_ApprovalKind> get _visibleKinds {
    final List<_ApprovalKind> out = List<_ApprovalKind>.from(_kinds);
    for (final WorkflowInstance i in _todo) {
      final String? n = i.templateName;
      if (n == null || n.isEmpty) continue;
      if (out.any((_ApprovalKind k) => k.name == n)) continue;
      out.add(_ApprovalKind(
          name: n, label: n, icon: Icons.approval_outlined, gradient: AppGradients.purple));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('审批'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: const TextStyle(color: AppPalette.inkMute)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: <Widget>[
                      if (_todo.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('当前没有待你审批的事项。',
                              style: TextStyle(color: AppPalette.inkMute)),
                        ),
                      ..._visibleKinds.map((_ApprovalKind k) {
                        final int n = _countOf(k.name);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ApprovalKindCard(
                            kind: k,
                            count: n,
                            onTap: () => context
                                .push('/approval/list?type=${Uri.encodeQueryComponent(k.name)}')
                                .then((_) => _load()),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _ApprovalKind {
  const _ApprovalKind({
    required this.name,
    required this.label,
    required this.icon,
    required this.gradient,
  });
  /// 与后端 workflow_template.name 一致，用于筛选。
  final String name;
  final String label;
  final IconData icon;
  final Gradient gradient;
}

class _ApprovalKindCard extends StatelessWidget {
  const _ApprovalKindCard({
    required this.kind,
    required this.count,
    required this.onTap,
  });
  final _ApprovalKind kind;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: <Widget>[
          AccentSquare(icon: kind.icon, gradient: kind.gradient),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(kind.label,
                    style: const TextStyle(
                        fontSize: AppFontSize.body, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(count == 0 ? '暂无待办' : '$count 项待审批',
                    style: const TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: AppPalette.danger, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppPalette.inkMute),
        ],
      ),
    );
  }
}

/// 某一审批类型的待办列表，可逐条「通过 / 驳回」。
class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({required this.type, super.key});

  /// 审批类型（后端模板名），为空表示全部。
  final String type;

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> {
  final WorkflowRepository _repo = WorkflowRepository();
  bool _loading = true;
  String? _error;
  List<WorkflowInstance> _items = <WorkflowInstance>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<WorkflowInstance> all = await _repo.listTodo();
      _items = widget.type.isEmpty
          ? all
          : all.where((WorkflowInstance i) => i.templateName == widget.type).toList();
      _error = null;
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 进审批详情页（业务单据 + 凭证大图 + 轨迹 + 通过/驳回）。
  /// 详情页审批成功后 pop(true)，这里据此刷新列表。
  Future<void> _open(WorkflowInstance item) async {
    final bool? changed =
        await context.push<bool>('/approval/detail', extra: item);
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.isEmpty ? '全部待办' : '${widget.type} · 待办'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppPalette.inkMute))))
              : _items.isEmpty
                  ? const Center(child: Text('暂无待审批事项',
                      style: TextStyle(color: AppPalette.inkMute)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext ctx, int i) {
                          final WorkflowInstance it = _items[i];
                          return _ApprovalTile(
                            item: it,
                            onOpen: () => _open(it),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// 待办卡片：整卡可点，进入详情页核对单据与凭证后再审批。
///
/// 这里**刻意不再放「通过 / 驳回」按钮** —— 审批人看不到附件（请款单与报销单的
/// 金额只存在于凭证图片里）就直接点通过，是真实出现过的坑。
class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.item,
    required this.onOpen,
  });
  final WorkflowInstance item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(item.summaryText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppFontSize.body)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item.currentNodeName ?? '审批中',
                    style: const TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.brand)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('申请人：${item.applicantName ?? '—'}',
              style: const TextStyle(
                  fontSize: AppFontSize.small, color: AppPalette.inkMute)),
          if (item.createTime != null && item.createTime!.length >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('提交时间：${item.createTime!.substring(0, 10)}',
                  style: const TextStyle(
                      fontSize: AppFontSize.small, color: AppPalette.inkMute)),
            ),
          if (item.formValues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...item.formValues.entries.map((MapEntry<String, dynamic> e) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${e.key}：${e.value}',
                      style: const TextStyle(
                          fontSize: AppFontSize.small, color: AppPalette.ink)),
                )),
          ],
          const SizedBox(height: 8),
          if (item.businessType != null && item.businessType!.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '含业务单据与凭证附件，请进详情核对后再审批',
                style: TextStyle(
                    fontSize: AppFontSize.small, color: AppPalette.inkMute),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('查看详情'),
            ),
          ),
        ],
      ),
    );
  }
}
