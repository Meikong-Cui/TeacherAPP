import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/features/auth/data/auth_repository.dart';
import 'package:teacher_app/shared/ui.dart';

/// 登录页（真实对接 OA 后台 /api/auth/login）。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userController =
      TextEditingController(text: 'teacher');
  final TextEditingController _pwdController =
      TextEditingController(text: '123456');
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await const AuthRepository()
          .login(_userController.text.trim(), _pwdController.text);
      if (!mounted) return;
      // 拉取后端真实用户信息（/api/me）覆盖本地 demo 默认（林嘉怡）。
      try {
        final TeacherUser me = await const AuthRepository().fetchMe();
        ref.read(currentUserProvider.notifier).state =
            ref.read(currentUserProvider).copyWith(
                  name: me.name,
                  role: me.role,
                  center: me.center,
                  avatar: me.avatar,
                );
      } catch (_) {
        // 兜底：退回到 JWT 中的姓名声明。
        final String? name = AuthStore.instance.userName;
        if (name != null && name.isNotEmpty) {
          ref.read(currentUserProvider.notifier).state =
              ref.read(currentUserProvider).copyWith(name: name);
        }
      }
      if (!mounted) return;
      ref.read(authChangedProvider.notifier).state++;
      context.go('/');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '网络异常，请检查后端是否启动');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            colors.primary,
                            colors.primary.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Spacer(),
                          const ThemeToggleButton(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '教师端登录',
                                    style: textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${AppConstants.brandName} · 康复管理系统',
                                    style: textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _userController,
                                    decoration: const InputDecoration(
                                      labelText: '工号 / 手机号',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? '请输入账号' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _pwdController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: '密码',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? '请输入密码' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  if (_error != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colors.errorContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _error!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _loading ? null : _submit,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('登 录'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      '演示账号：teacher / 123456',
                                      style: textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
