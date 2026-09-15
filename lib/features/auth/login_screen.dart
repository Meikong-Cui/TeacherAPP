import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/features/auth/data/auth_repository.dart';
import 'package:teacher_app/shared/ui.dart';

/// 卡片圆角（设计稿 28）。
const double _kGlassRadius = 28;

/// 毛玻璃模糊强度。换算关系：Flutter 的 sigma ≈ CSS `backdrop-filter: blur(px) / 2`，
/// 设计稿给的是 CSS 24px，所以这里取 12。
const double _kBlurSigma = 12;

/// 登录页（真实对接 OA 后台 /api/auth/login）。
///
/// 视觉方案取自设计预览页 `teacher_app/design_preview/login_glass.html`：
/// 全屏渐变光斑背景 + 居中毛玻璃卡片，参数为「品牌青底 / 轻盈细线标题 / 圆角 28」。
/// 玻璃明暗两套值随系统主题切换：
///   深色玻璃 底色 white 0.115 · 描边 white 0.26
///   浅色玻璃 底色 white 0.520 · 描边 white 0.85
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
  bool _obscure = true;
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

  /// 后端暂无自助重置接口，给一个明确出口，而不是留一条点不动的死链。
  void _onForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请联系园区管理员重置密码')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _GlassSkin skin = isDark ? _GlassSkin.dark : _GlassSkin.light;

    return Scaffold(
      backgroundColor: skin.base.first,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildBackground(skin),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: <Widget>[
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: skin.chipFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: skin.chipBorder),
                        ),
                        child: ThemeToggleButton(
                          dense: true,
                          iconSize: 18,
                          color: skin.fg,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          // 空间富余时垂直居中，软键盘顶上来后自动变成可滚动。
                          constraints: BoxConstraints(
                            minHeight: (c.maxHeight - 32)
                                .clamp(0.0, double.infinity),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[_buildCard(skin)],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 背景 ──────────────────────────────────────────────────────────────

  Widget _buildBackground(_GlassSkin skin) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: skin.base,
            ),
          ),
        ),
        _glow(skin.blobs[0], 330, const Alignment(-0.95, -0.90)),
        _glow(skin.blobs[1], 260, const Alignment(1.05, -0.40)),
        _glow(skin.blobs[2], 340, const Alignment(-0.80, 1.00)),
        _glow(skin.blobs[3], 200, const Alignment(0.85, 0.20)),
      ],
    );
  }

  /// 光斑：用径向渐变模拟 CSS 里 `filter: blur(46px)` 的色块。
  /// 走渐变而不是再叠一层 ImageFiltered —— 少一层离屏渲染，观感也更柔。
  Widget _glow(Color color, double size, Alignment at) {
    return Align(
      alignment: at,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: 0.85),
                color.withValues(alpha: 0.38),
                color.withValues(alpha: 0),
              ],
              stops: const <double>[0, 0.5, 1],
            ),
          ),
        ),
      ),
    );
  }

  // ── 玻璃卡片 ──────────────────────────────────────────────────────────

  Widget _buildCard(_GlassSkin skin) {
    return Container(
      // 阴影必须放在 ClipRRect 外层：塞进被裁剪的子树里会被一起剪掉，等于没阴影。
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kGlassRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kGlassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: skin.glassFill,
              borderRadius: BorderRadius.circular(_kGlassRadius),
              border: Border.all(color: skin.glassBorder, width: 1),
            ),
            child: Stack(
              children: <Widget>[
                // 斜向高光：毛玻璃「有厚度」的关键，缺了就像一块灰塑料。
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kGlassRadius),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            skin.glassSheen,
                            skin.glassSheen.withValues(alpha: 0),
                          ],
                          stops: const <double>[0, 0.42],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: _buildForm(skin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 表单 ──────────────────────────────────────────────────────────────

  Widget _buildForm(_GlassSkin skin) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildBrand(skin),
          const SizedBox(height: 20),
          Text(
            '教师端登录',
            style: TextStyle(
              // 「轻盈细线」：候选链整条都是黑体，三端都不会出现字体类别翻转。
              fontFamilyFallback: AppFontFamily.thinSansCjk,
              fontSize: 27,
              height: 1.24,
              // 0.12em ≈ 27 × 0.12：细体得靠字距撑开，否则显得松散。
              letterSpacing: 3,
              fontWeight: AppFontWeight.light,
              color: skin.fg,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '康复管理系统 · 教师工作台',
            style: TextStyle(
              fontFamilyFallback: AppFontFamily.sansCjk,
              fontSize: 12,
              letterSpacing: 0.8,
              color: skin.fgMute,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  skin.glassBorder,
                  skin.glassBorder.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _GlassField(
            label: '工号 / 手机号',
            controller: _userController,
            icon: Icons.person_outline_rounded,
            skin: skin,
            validator: (String? v) =>
                (v == null || v.isEmpty) ? '请输入账号' : null,
          ),
          const SizedBox(height: 14),
          _GlassField(
            label: '密码',
            controller: _pwdController,
            icon: Icons.lock_outline_rounded,
            skin: skin,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            validator: (String? v) =>
                (v == null || v.isEmpty) ? '请输入密码' : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _onForgotPassword,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Text(
                  '忘记密码？',
                  style: TextStyle(
                    fontFamilyFallback: AppFontFamily.sansCjk,
                    fontSize: 12,
                    color: skin.fgMute,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildError(skin),
          ],
          const SizedBox(height: 18),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildBrand(_GlassSkin skin) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppPalette.brandSoft, AppPalette.brand],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xBF14B8A6),
                blurRadius: 16,
                spreadRadius: -6,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppConstants.brandLatin,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.3,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
                color: skin.fgMute,
              ),
            ),
            Text(
              AppConstants.brandName,
              style: TextStyle(
                fontFamilyFallback: AppFontFamily.sansCjk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skin.fg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError(_GlassSkin skin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: skin.errorFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 16, color: skin.errorText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontFamilyFallback: AppFontFamily.sansCjk,
                fontSize: 12.5,
                height: 1.4,
                color: skin.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppPalette.brandSoft,
            AppPalette.brand,
            AppPalette.brandDark,
          ],
          stops: <double>[0, 0.62, 1],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xD914B8A6),
            blurRadius: 26,
            spreadRadius: -10,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _loading ? null : _submit,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF02211E),
                    ),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: Color(0xFF02211E),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── 玻璃主题色板 ────────────────────────────────────────────────────────
//
// 数值来自设计预览页。注释里的 white x.xxx 就是设计稿的写法，
// 这里写成 const ARGB 是为了保住 const 构造（alpha 与 withOpacity 完全等价）。
class _GlassSkin {
  const _GlassSkin({
    required this.base,
    required this.blobs,
    required this.fg,
    required this.fgMute,
    required this.glassFill,
    required this.glassBorder,
    required this.glassSheen,
    required this.inputFill,
    required this.inputBorder,
    required this.chipFill,
    required this.chipBorder,
    required this.errorFill,
    required this.errorBorder,
    required this.errorText,
  });

  final List<Color> base;
  final List<Color> blobs;
  final Color fg;
  final Color fgMute;
  final Color glassFill;
  final Color glassBorder;
  final Color glassSheen;
  final Color inputFill;
  final Color inputBorder;
  final Color chipFill;
  final Color chipBorder;
  final Color errorFill;
  final Color errorBorder;
  final Color errorText;

  /// 深色玻璃：底色 white 0.115 · 描边 white 0.26
  static const _GlassSkin dark = _GlassSkin(
    base: <Color>[Color(0xFF04211F), Color(0xFF062B28), Color(0xFF0A3A36)],
    blobs: <Color>[
      AppPalette.brand,
      Color(0xFF0EA5E9),
      AppPalette.brandSoft,
      Color(0xFF2DD4BF),
    ],
    fg: Color(0xFFEAF6F4),
    fgMute: Color(0x9EE2F2F0),
    glassFill: Color(0x1DFFFFFF), // white 0.115
    glassBorder: Color(0x42FFFFFF), // white 0.26
    glassSheen: Color(0x29FFFFFF), // white 0.16
    inputFill: Color(0x13FFFFFF), // white 0.075
    inputBorder: Color(0x29FFFFFF), // white 0.16
    chipFill: Color(0x1AFFFFFF), // white 0.10
    chipBorder: Color(0x33FFFFFF), // white 0.20
    errorFill: Color(0x33E2683B),
    errorBorder: Color(0x66E2683B),
    errorText: Color(0xFFFFB59A),
  );

  /// 浅色玻璃：底色 white 0.520 · 描边 white 0.85
  static const _GlassSkin light = _GlassSkin(
    base: <Color>[Color(0xFFEAFBF7), Color(0xFFDDF5F1), Color(0xFFCFEFEA)],
    blobs: <Color>[
      AppPalette.brandSoft,
      Color(0xFF7BB7FF),
      Color(0xFF99F6E4),
      Color(0xFFA7F3D0),
    ],
    fg: Color(0xFF0E2724),
    fgMute: Color(0x99102A27),
    glassFill: Color(0x85FFFFFF), // white 0.520
    glassBorder: Color(0xD9FFFFFF), // white 0.85
    glassSheen: Color(0x73FFFFFF), // white 0.45
    inputFill: Color(0x80FFFFFF), // white 0.50
    inputBorder: Color(0xD9FFFFFF), // white 0.85
    chipFill: Color(0x8CFFFFFF), // white 0.55
    chipBorder: Color(0xD9FFFFFF), // white 0.85
    errorFill: Color(0x1FE2683B),
    errorBorder: Color(0x59E2683B),
    errorText: Color(0xFF8A2C12),
  );
}

/// 玻璃输入框：外置标签（宽字距小字）+ 半透明输入区 + 聚焦青色描边。
class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.skin,
    required this.validator,
    this.obscure = false,
    this.onToggleObscure,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final _GlassSkin skin;
  final FormFieldValidator<String> validator;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: skin.inputBorder, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamilyFallback: AppFontFamily.sansCjk,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w500,
            color: skin.fgMute,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          cursorColor: AppPalette.brandSoft,
          style: TextStyle(
            fontFamilyFallback: AppFontFamily.sansCjk,
            fontSize: 14.5,
            letterSpacing: 0.2,
            color: skin.fg,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: skin.inputFill,
            isDense: true,
            // left 交给 prefixIcon 占位，避免图标把文字推得过右。
            contentPadding: const EdgeInsets.only(
              left: 0,
              right: 14,
              top: 15,
              bottom: 15,
            ),
            prefixIcon: Icon(icon, size: 18, color: skin.fgMute),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    iconSize: 18,
                    color: skin.fgMute,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
            border: base,
            enabledBorder: base,
            disabledBorder: base,
            focusedBorder: base.copyWith(
              borderSide:
                  const BorderSide(color: Color(0xBF5EEAD4), width: 1.2),
            ),
            errorBorder: base.copyWith(
              borderSide: BorderSide(color: skin.errorBorder, width: 1),
            ),
            focusedErrorBorder: base.copyWith(
              borderSide: BorderSide(color: skin.errorBorder, width: 1.2),
            ),
            errorStyle: TextStyle(
              fontFamilyFallback: AppFontFamily.sansCjk,
              fontSize: 11.5,
              height: 1.4,
              color: skin.errorText,
            ),
            hintStyle: TextStyle(
              fontFamilyFallback: AppFontFamily.sansCjk,
              fontSize: 14,
              color: skin.fgMute,
            ),
          ),
        ),
      ],
    );
  }
}
