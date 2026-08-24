import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/supplement/supplement_repository.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// 「办公」→「补卡」列表页（教师端）。数据与 OA 网页共用 /api/oa/record
/// category='supplement-card'；审批进度由通用流程引擎「补卡申请」实例驱动。
/// 审批通过后，后端会自动写入一条「员工打卡」记录。
class SupplementListScreen extends ConsumerStatefulWidget {
  const SupplementListScreen({super.key});

  @override
  ConsumerState<SupplementListScreen> createState() =>
      _SupplementListScreenState();
}

class _SupplementListScreenState extends ConsumerState<SupplementListScreen> {
  final SupplementRepository _repo = SupplementRepository();
  List<SupplementRecord> _list = const <SupplementRecord>[];
  Map<int, WorkflowInstance> _wfMap = const <int, WorkflowInstance>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SupplementRecord> rows =
          await _repo.listSupplements(keyword: keyword);
      final Map<int, WorkflowInstance> wfMap = <int, WorkflowInstance>{};
      await Future.wait(rows
          .where((SupplementRecord r) => r.id != null && r.id! > 0)
          .map((SupplementRecord r) async {
        final WorkflowInstance? wf =
            await WorkflowRepository().findByBusiness('oa_record', r.id!);
        if (wf != null) wfMap[r.id!] = wf;
      }));
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
        title: const Text('补卡',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _list.isEmpty
                  ? _EmptyState(onApply: () => _goApply(context))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _list.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final SupplementRecord r = _list[i];
                          return _SupplementCard(
                            record: r,
                            wf: r.id == null ? null : _wfMap[r.id!],
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goApply(context),
        icon: const Icon(Icons.add),
        label: const Text('新增补卡'),
      ),
    );
  }

  Future<void> _goApply(BuildContext context) async {
    final bool? ok = await context.push<bool>('/supplement/new');
    if (ok == true) _load();
  }
}

class _SupplementCard extends StatelessWidget {
  const _SupplementCard({required this.record, this.wf});
  final SupplementRecord record;
  final WorkflowInstance? wf;

  @override
  Widget build(BuildContext context) {
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
                      color: AppPalette.brandDark, fontWeight: FontWeight.bold),
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
                    Text(record.supplementDate,
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                AppChip(record.supplementType, tone: AppPalette.warning),
                if (wf != null && wf!.pending && wf!.currentNodeName != null)
                  AppChip('当前：${wf!.currentNodeName}',
                      tone: AppPalette.brandDark),
                if (wf != null && wf!.status == 2)
                  AppChip('已补记打卡', tone: AppPalette.success),
              ],
            ),
            if (record.reason.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('原因：${record.reason}',
                  style: const TextStyle(
                    fontSize: AppFontSize.small,
                    color: AppPalette.ink,
                  )),
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
                icon: Icons.fact_check_outlined,
                gradient: AppGradients.amber,
                size: 56),
            const SizedBox(height: 12),
            const Text('还没有补卡记录',
                style: TextStyle(
                    fontSize: AppFontSize.title, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '漏打卡时提交补卡，直属上级审批通过后\n系统自动补记考勤。',
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
              label: const Text('提交补卡'),
            ),
          ]),
        ),
      ),
    );
  }
}
