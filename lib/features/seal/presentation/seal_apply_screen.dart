import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/seal/data/seal_repository.dart';

/// 用章申请表单：教师填写印章类型 / 事由 / 备注，并自行选择审批人，
/// 提交后走通用流程引擎「用章申请」模板（发起人自选审批人）。
class SealApplyScreen extends ConsumerStatefulWidget {
  const SealApplyScreen({super.key});

  @override
  ConsumerState<SealApplyScreen> createState() => _SealApplyScreenState();
}

class _SealApplyScreenState extends ConsumerState<SealApplyScreen> {
  static const List<String> _sealTypes = <String>['公章', '财务章', '合同章'];

  String _type = '公章';
  final TextEditingController _purposeCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  int? _approverId;
  List<_UserOption> _users = const <_UserOption>[];
  bool _loadingUsers = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      // 任何已登录用户均可搜索员工（用于自选审批人），仅返回非删除用户
      final dynamic raw = await apiClient.get('/api/system/users/search',
          params: <String, dynamic>{'size': 200});
      final List<dynamic> list = (raw is List) ? raw : <dynamic>[];
      final List<_UserOption> opts = list.whereType<Map<String, dynamic>>().map((e) {
        final int id = (e['id'] as num?)?.toInt() ?? 0;
        final String name =
            (e['name'] as String?) ?? (e['username'] as String?) ?? '';
        return _UserOption(id: id, name: name);
      }).toList();
      if (mounted) setState(() => _users = opts);
    } catch (e) {
      // 审批人列表加载失败时仍可提交，仅无法选择审批人
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  bool get _canSubmit =>
      !_submitting && _purposeCtrl.text.trim().isNotEmpty && _approverId != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final String employee = AuthStore.instance.userName ?? '未知教师';
    final SealRecord r = SealRecord(
      employee: employee,
      sealType: _type,
      purpose: _purposeCtrl.text.trim(),
      remark: _remarkCtrl.text.trim(),
      status: 1,
    );
    setState(() => _submitting = true);
    try {
      final SealSubmitResult res = await SealRepository().submitSeal(r, _approverId!);
      if (!mounted) return;
      if (res.recordId == 0) throw Exception('创建用章记录失败');
      String approverName = '';
      for (final _UserOption u in _users) {
        if (u.id == _approverId) {
          approverName = u.name;
          break;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.hasWorkflow
              ? '用章申请已提交，等待 $approverName 审批'
              : '用章申请已提交，OA 后台可查看并审批'),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用章申请',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        actions: <Widget>[
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('提交'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('申请人',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 4),
                Text(AuthStore.instance.userName ?? '—',
                    style: const TextStyle(
                        fontSize: AppFontSize.title, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('印章类型',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _sealTypes.map((String t) {
                    final bool selected = t == _type;
                    return ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (_) => setState(() => _type = t),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('用章事由',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                TextField(
                  controller: _purposeCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '请说明本次用章的具体事项',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('备注',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                TextField(
                  controller: _remarkCtrl,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '选填',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('审批人',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                if (_loadingUsers)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_users.isEmpty)
                  const Text('暂无可选审批人',
                      style: TextStyle(color: AppPalette.inkMute))
                else
                  DropdownButtonFormField<int>(
                    value: _approverId,
                    decoration: const InputDecoration(
                      hintText: '选择审批人',
                      border: OutlineInputBorder(),
                    ),
                    items: _users
                        .map((_UserOption u) => DropdownMenuItem<int>(
                              value: u.id,
                              child: Text(u.name),
                            ))
                        .toList(),
                    onChanged: (int? v) => setState(() => _approverId = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting ? '提交中…' : '提交用章申请'),
          ),
        ],
      ),
    );
  }
}

class _UserOption {
  const _UserOption({required this.id, required this.name});
  final int id;
  final String name;
}
