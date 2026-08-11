import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 康复档案列表（教师查看名下儿童档案，点击进入详情填写/上传）。
class RehabArchiveListScreen extends ConsumerStatefulWidget {
  const RehabArchiveListScreen({super.key});

  @override
  ConsumerState<RehabArchiveListScreen> createState() =>
      _RehabArchiveListScreenState();
}

class _RehabArchiveListScreenState
    extends ConsumerState<RehabArchiveListScreen> {
  final TextEditingController _search = TextEditingController();
  List<RehabArchive> _list = const <RehabArchive>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? keyword}) async {
    setState(() => _loading = true);
    try {
      final List<RehabArchive> list =
          await ref.read(rehabRepositoryProvider).listArchives(keyword: keyword);
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('康复档案')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索儿童姓名 / 档案编号',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    _load(keyword: '');
                  },
                ),
              ),
              onSubmitted: (v) => _load(keyword: v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _list.isEmpty
                        ? const Center(child: Text('暂无康复档案'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final RehabArchive a = _list[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.onPrimaryContainer,
                                    child: Text(
                                      a.childName.isNotEmpty ? a.childName[0] : '?',
                                    ),
                                  ),
                                  title: Text(a.childName),
                                  subtitle: Text(
                                    '${a.archiveNo} · ${a.campusName}',
                                  ),
                                  trailing: StatusChip(a.status.label),
                                  onTap: () => context.push(
                                      a.isAutism
                                          ? '/rehab-autism/${a.id}'
                                          : '/rehab/${a.id}'),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
