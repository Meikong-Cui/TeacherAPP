import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/features/office/mailbox_repository.dart';

/// 「员工信箱」→ 写消息：选择收件人（可多选中即群发）+ 文字 + 图片。
///
/// 发送后每人各收到一条站内信通知（后端 /api/mailbox/send），
/// 消息在收件箱保留 30 天。
class MailboxComposeScreen extends StatefulWidget {
  const MailboxComposeScreen({super.key});

  @override
  State<MailboxComposeScreen> createState() => _MailboxComposeScreenState();
}

class _MailboxComposeScreenState extends State<MailboxComposeScreen> {
  final MailboxRepository _repo = MailboxRepository();
  final TextEditingController _contentCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<MailboxUser> _users = const <MailboxUser>[];
  final Set<int> _selected = <int>{};
  final List<String> _images = <String>[];

  bool _loadingUsers = true;
  bool _sending = false;
  bool _uploading = false;
  String? _error;

  int? get _selfId => int.tryParse(AuthStore.instance.userId ?? '');

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final List<MailboxUser> list = await _repo.listUsers();
      final int? self = _selfId;
      if (!mounted) return;
      setState(() {
        _users = (self == null)
            ? list
            : list.where((MailboxUser u) => u.id != self).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '员工列表加载失败：$e');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  bool get _canSend =>
      !_sending &&
      !_uploading &&
      _selected.isNotEmpty &&
      (_contentCtrl.text.trim().isNotEmpty || _images.isNotEmpty);

  Future<void> _pickImages() async {
    if (_images.length >= 9) {
      _toast('最多上传 9 张图片');
      return;
    }
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      if (files.isEmpty || !mounted) return;
      setState(() {
        _uploading = true;
        _error = null;
      });
      final List<String> uploaded = <String>[];
      for (final XFile f in files) {
        if (_images.length + uploaded.length >= 9) break;
        try {
          uploaded.add(await _repo.uploadImage(f.path));
        } catch (e) {
          if (mounted) _toast('部分图片上传失败：$e');
        }
      }
      if (!mounted) return;
      setState(() => _images.addAll(uploaded));
    } catch (e) {
      if (mounted) _toast('选择图片失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final int id = await _repo.send(
        recipientIds: _selected.toList(),
        content: _contentCtrl.text.trim(),
        images: List<String>.from(_images),
      );
      if (!mounted) return;
      if (id == 0) throw Exception('发送失败，请重试');
      _toast('已发送给 ${_selected.length} 位同事');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '发送失败：$e';
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openPicker() async {
    final Set<int>? picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _RecipientPickerSheet(
        users: _users,
        selected: Set<int>.from(_selected),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<MailboxUser> chosen =
        _users.where((MailboxUser u) => _selected.contains(u.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('写消息',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        actions: <Widget>[
          TextButton(
            onPressed: _canSend ? _send : null,
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('发送'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('收件人',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (_selected.isNotEmpty)
                      AppChip('${_selected.length} 人', tone: AppPalette.brandDark),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loadingUsers ? null : _openPicker,
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('选择'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingUsers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else if (chosen.isEmpty)
                  const Text('请选择一位或多位同事（多选即群发）',
                      style: TextStyle(
                          fontSize: AppFontSize.small,
                          color: AppPalette.inkMute))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: chosen
                        .map((MailboxUser u) => Chip(
                              label: Text(u.name),
                              onDeleted: () =>
                                  setState(() => _selected.remove(u.id)),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _contentCtrl,
              maxLines: 6,
              minLines: 4,
              maxLength: 500,
              onChanged: (String _) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '输入消息内容（可不填，直接发图片）',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('图片',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('${_images.length}/9',
                        style: const TextStyle(
                            fontSize: AppFontSize.small,
                            color: AppPalette.inkMute)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _uploading ? null : _pickImages,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.image_outlined, size: 18),
                      label: const Text('添加'),
                    ),
                  ],
                ),
                if (_images.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (BuildContext ctx, int i) => Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: Image.network(
                              _images[i].startsWith('http')
                                  ? _images[i]
                                  : '${AppConstants.apiBaseUrl}${_images[i]}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppPalette.line,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppPalette.inkMute),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: const TextStyle(
                    fontSize: AppFontSize.small, color: AppPalette.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text('消息保留 30 天，过期后不再显示。',
              style: TextStyle(
                  fontSize: AppFontSize.small, color: AppPalette.inkMute)),
        ],
      ),
    );
  }
}

/// 收件人选择器：搜索 + 多选 + 全选（群发）。
class _RecipientPickerSheet extends StatefulWidget {
  const _RecipientPickerSheet({required this.users, required this.selected});

  final List<MailboxUser> users;
  final Set<int> selected;

  @override
  State<_RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<_RecipientPickerSheet> {
  final TextEditingController _kwCtrl = TextEditingController();
  late Set<int> _picked;
  String _kw = '';

  @override
  void initState() {
    super.initState();
    _picked = Set<int>.from(widget.selected);
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  List<MailboxUser> get _visible {
    if (_kw.isEmpty) return widget.users;
    return widget.users
        .where((MailboxUser u) => u.name.contains(_kw))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<MailboxUser> list = _visible;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('选择收件人',
                      style: TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    final bool allPicked =
                        list.every((MailboxUser u) => _picked.contains(u.id));
                    if (allPicked) {
                      _picked.removeAll(list.map((MailboxUser u) => u.id));
                    } else {
                      _picked.addAll(list.map((MailboxUser u) => u.id));
                    }
                  }),
                  child: const Text('全选/取消'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _kwCtrl,
              decoration: const InputDecoration(
                hintText: '搜索姓名',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (String v) => setState(() => _kw = v.trim()),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (BuildContext ctx, int i) {
                final MailboxUser u = list[i];
                final bool on = _picked.contains(u.id);
                return CheckboxListTile(
                  value: on,
                  title: Text(u.name),
                  onChanged: (bool? v) => setState(() {
                    if (v == true) {
                      _picked.add(u.id);
                    } else {
                      _picked.remove(u.id);
                    }
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_picked),
                child: Text('确定（已选 ${_picked.length} 人）'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
