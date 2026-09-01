import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/office/mailbox_repository.dart';

/// 「办公」→「员工信箱」：收件箱 / 已发送两个页签。
///
/// 数据来自后端 oa-workflow 的 `/api/mailbox/*`：一条消息可发给多人（群发），
/// 收件人收到站内信通知后在此查看发送者与内容；消息保留 30 天。
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen>
    with SingleTickerProviderStateMixin {
  final MailboxRepository _repo = MailboxRepository();
  late final TabController _tabController;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _goCompose() async {
    final bool? ok = await context.push<bool>('/office/mailbox/compose');
    if (ok == true && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('员工信箱',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: '收件箱'),
            Tab(text: '已发送'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _MailboxList(
            key: ValueKey<int>(_version * 10 + 1),
            repository: _repo,
            kind: _MailboxKind.inbox,
          ),
          _MailboxList(
            key: ValueKey<int>(_version * 10 + 2),
            repository: _repo,
            kind: _MailboxKind.outbox,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCompose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('写消息'),
      ),
    );
  }
}

enum _MailboxKind { inbox, outbox }

class _MailboxList extends StatefulWidget {
  const _MailboxList({
    super.key,
    required this.repository,
    required this.kind,
  });

  final MailboxRepository repository;
  final _MailboxKind kind;

  @override
  State<_MailboxList> createState() => _MailboxListState();
}

class _MailboxListState extends State<_MailboxList> {
  List<MailboxMessage> _list = const <MailboxMessage>[];
  bool _loading = true;
  String? _error;

  bool get _isInbox => widget.kind == _MailboxKind.inbox;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<MailboxMessage> rows = _isInbox
          ? await widget.repository.inbox()
          : await widget.repository.outbox();
      if (!mounted) return;
      setState(() => _list = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MailboxMessage m) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _MailboxDetailSheet(message: m, isInbox: _isInbox),
    );
    // 收件箱打开即已读
    if (_isInbox && m.unread) {
      try {
        await widget.repository.markRead(m.id);
        if (mounted) {
          setState(() {
            _list = _list
                .map((MailboxMessage e) =>
                    e.id == m.id ? _copyWithRead(e) : e)
                .toList();
          });
        }
      } catch (_) {
        // 标记已读失败不影响浏览
      }
    }
  }

  MailboxMessage _copyWithRead(MailboxMessage src) => MailboxMessage(
        id: src.id,
        senderId: src.senderId,
        senderName: src.senderName,
        content: src.content,
        images: src.images,
        createTime: src.createTime,
        readFlag: 1,
        recipients: src.recipients,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48, color: AppPalette.danger),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SoftCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AccentSquare(
                    icon: Icons.mail_outline_rounded,
                    gradient: AppGradients.sky,
                    size: 56),
                const SizedBox(height: 12),
                Text(_isInbox ? '暂无消息' : '还没有发送消息',
                    style: const TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isInbox
                      ? '同事通过员工信箱发给你的消息会出现在这里\n（消息保留 30 天）'
                      : '点击右下角「写消息」给同事发消息\n可一次选择多位收件人群发',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: AppFontSize.small, color: AppPalette.inkMute),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _list.length,
        itemBuilder: (BuildContext ctx, int i) => _MailboxCard(
          message: _list[i],
          isInbox: _isInbox,
          onTap: () => _open(_list[i]),
        ),
      ),
    );
  }
}

class _MailboxCard extends StatelessWidget {
  const _MailboxCard({
    required this.message,
    required this.isInbox,
    required this.onTap,
  });

  final MailboxMessage message;
  final bool isInbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String who =
        isInbox ? message.senderName : _recipientLine(message);
    final DateTime? t = message.createTime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppPalette.brand.withOpacity(0.16),
                  child: Text(
                    message.senderName.isNotEmpty ? message.senderName[0] : '?',
                    style: const TextStyle(
                        color: AppPalette.brandDark, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isInbox ? '来自 $who' : '发给 $who',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.bold),
                      ),
                      if (t != null)
                        Text(DateFormat('MM-dd HH:mm').format(t),
                            style: const TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.inkMute)),
                    ],
                  ),
                ),
                if (isInbox && message.unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppPalette.danger, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFontSize.small, color: AppPalette.ink),
            ),
            if (message.images.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (BuildContext ctx, int i) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: Image.network(
                      message.imageUrl(message.images[i]),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppPalette.line,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppPalette.inkMute),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _recipientLine(MailboxMessage m) {
    if (m.recipients.isEmpty) return '—';
    if (m.recipients.length == 1) return m.recipients.first.name;
    return '${m.recipients.first.name} 等 ${m.recipients.length} 人';
  }
}

/// 消息详情（底部弹层）：发送者 / 时间 / 正文 / 图片（点击放大）/ 已读情况。
class _MailboxDetailSheet extends StatelessWidget {
  const _MailboxDetailSheet({required this.message, required this.isInbox});

  final MailboxMessage message;
  final bool isInbox;

  @override
  Widget build(BuildContext context) {
    final DateTime? t = message.createTime;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppPalette.brand.withOpacity(0.16),
                  child: Text(
                    message.senderName.isNotEmpty ? message.senderName[0] : '?',
                    style: const TextStyle(
                        color: AppPalette.brandDark, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(message.senderName,
                          style: const TextStyle(
                              fontSize: AppFontSize.title,
                              fontWeight: FontWeight.bold)),
                      if (t != null)
                        Text(DateFormat('yyyy-MM-dd HH:mm').format(t),
                            style: const TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.inkMute)),
                    ],
                  ),
                ),
              ],
            ),
            if (message.content.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(message.content,
                  style: const TextStyle(
                      fontSize: AppFontSize.body, height: 1.5)),
            ],
            if (message.images.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: message.images.length,
                itemBuilder: (BuildContext ctx, int i) => GestureDetector(
                  onTap: () => _preview(context, message.imageUrl(message.images[i])),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: Image.network(
                      message.imageUrl(message.images[i]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppPalette.line,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppPalette.inkMute),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (isInbox)
              Text(message.unread ? '未读' : '已读',
                  style: const TextStyle(
                      fontSize: AppFontSize.small, color: AppPalette.inkMute))
            else ...<Widget>[
              const Text('收件人',
                  style: TextStyle(
                      fontSize: AppFontSize.small, color: AppPalette.inkMute)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.recipients
                    .map((MailboxRecipient r) => AppChip(
                          '${r.name}${r.readFlag == 1 ? ' · 已读' : ' · 未读'}',
                          tone: r.readFlag == 1 ? AppPalette.success : AppPalette.inkMute,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _preview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: InteractiveViewer(
            child: Image.network(url,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white, size: 48)),
          ),
        ),
      ),
    );
  }
}
