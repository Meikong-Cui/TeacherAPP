import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/office/leave_repository.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// 「办公」→「请假」列表页。
/// 数据与 OA 网页共用 /api/oa/record category='hr-leave' 接口。
class LeaveListScreen extends ConsumerStatefulWidget {
  const LeaveListScreen({super.key});

  @override
  ConsumerState<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends ConsumerState<LeaveListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final LeaveRepository _repo = LeaveRepository();
  List<LeaveRecord> _list = const <LeaveRecord>[];
  Map<int, WorkflowInstance> _wfMap = const <int, WorkflowInstance>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<LeaveRecord> rows = await _repo.listLeaves(keyword: keyword);
      // 关联每条请假的审批流实例，用于展示审批进度
      final Map<int, WorkflowInstance> wfMap = <int, WorkflowInstance>{};
      await Future.wait(rows.where((LeaveRecord r) => r.id != null && r.id! > 0).map(
        (LeaveRecord r) async {
          final WorkflowInstance? wf =
              await WorkflowRepository().findByBusiness('oa_record', r.id!);
          if (wf != null) wfMap[r.id!] = wf;
        },
      ));
      if (!mounted) return;
      setState(() {
        _list = rows;
        _wfMap = wfMap;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('请假',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索员工 / 类型 / 事由',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load(keyword: '');
                        },
                      ),
              ),
              onSubmitted: (String v) => _load(keyword: v),
              onChanged: (String _) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _list.isEmpty
                        ? _EmptyState(
                            onApply: () => _goApply(context),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: _list.length,
                              itemBuilder: (BuildContext ctx, int i) {
                                final LeaveRecord r = _list[i];
                                return _LeaveCard(
                                  record: r,
                                  wf: r.id == null ? null : _wfMap[r.id!],
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goApply(context),
        icon: const Icon(Icons.add),
        label: const Text('新增请假'),
      ),
    );
  }

  Future<void> _goApply(BuildContext context) async {
    final bool? ok = await context.push<bool>('/office/leave/new');
    if (ok == true) _load();
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.record, this.wf});
  final LeaveRecord record;
  final WorkflowInstance? wf;

  @override
  Widget build(BuildContext context) {
    // 审批流状态优先于记录自身状态展示进度
    final String statusLabel = wf != null ? wf!.statusLabel : record.statusLabel;
    final Color statusTone = wf != null
        ? (wf!.status == 2
            ? AppPalette.success
            : wf!.status == 3
                ? AppPalette.danger
                : AppPalette.warning)
        : AppPalette.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppPalette.brand.withOpacity(0.16),
                child: Text(
                  record.employee.isNotEmpty ? record.employee[0] : '?',
                  style: const TextStyle(
                      color: AppPalette.brandDark,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(record.employee,
                        style: const TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.bold,
                        )),
                    Text('${record.startDate} ~ ${record.endDate}',
                        style: const TextStyle(
                          fontSize: AppFontSize.small,
                          color: AppPalette.inkMute,
                        )),
                  ],
                ),
              ),
              AppChip(statusLabel, tone: statusTone),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
              AppChip(record.leaveType, tone: AppPalette.warning),
              if (record.days != null)
                AppChip('${record.days} 天', tone: AppPalette.brandDark),
              if (wf != null && wf!.pending && wf!.currentNodeName != null)
                AppChip('当前：${wf!.currentNodeName}', tone: AppPalette.brandDark),
            ]),
            if (record.reason != null && record.reason!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('事由：${record.reason}',
                  style: const TextStyle(
                    fontSize: AppFontSize.small,
                    color: AppPalette.ink)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onApply});
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SoftCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const AccentSquare(
                icon: Icons.event_busy_outlined,
                gradient: AppGradients.amber,
                size: 56),
            const SizedBox(height: 12),
            const Text('还没有请假记录',
                style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '教师端提交后，OA 网页「人事-请假」处\n管理员可统一查看并审批。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.small,
                color: AppPalette.inkMute,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.add),
              label: const Text('提交请假'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline,
              size: 56, color: AppPalette.danger),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
