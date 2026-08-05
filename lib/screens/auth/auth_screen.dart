import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';

/// Экран входа / регистрации. Обычно показывается поверх текущего экрана
/// (push), когда действие требует авторизации (сохранить место, оставить
/// отзыв и т.п.) — тогда после успеха сам себя закрывает (pop).
/// При обязательной регистрации на первом запуске (см. main.dart) вместо
/// pop вызывается [onAuthenticated], а [dismissible]=false прячет крестик —
/// экран нельзя закрыть, не войдя в аккаунт.
/// Закрытие отслеживается через authStateChanges, а не сразу после
/// await signIn/signUp — это заодно ловит и вход через Google (OAuth
/// возвращается в приложение через deep link, а не через этот await).
class AuthScreen extends StatefulWidget {
  final bool dismissible;
  final VoidCallback? onAuthenticated;
  const AuthScreen({super.key, this.dismissible = true, this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _handledAuth = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = SupabaseService.authStateChanges.listen((_) {
      if (!mounted || _handledAuth || SupabaseService.currentUser == null) return;
      _handledAuth = true;
      if (widget.onAuthenticated != null) {
        widget.onAuthenticated!();
      } else {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 6) return false;
    if (_isSignUp && _nameController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await SupabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      } else {
        await SupabaseService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (!mounted) return;

      // Закрытие/переход при успехе — через authStateChanges (см. initState),
      // единая точка и для входа по паролю, и для регистрации, и для Google.
      if (SupabaseService.currentUser != null) return;

      // Регистрация прошла, но требуется подтверждение почты — сессии ещё нет.
      setState(() {
        _isSubmitting = false;
        _isSignUp = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).checkEmailSnackbar)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = s(context).genericError;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isGoogleSubmitting) return;
    setState(() {
      _isGoogleSubmitting = true;
      _error = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
      // На вебе и на мобильных это открывает системный браузер/окно Google
      // и возвращается в приложение через redirect — сам экран закроется
      // через authStateChanges у вызывающего экрана, здесь просто снимаем
      // индикатор загрузки на случай, если пользователь отменит вход.
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s(context).googleSignInError);
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.dismissible
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp ? s(context).createAccountTitle : s(context).welcomeBackTitle,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp ? s(context).signUpSubtitle : s(context).signInSubtitleAuth,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGoogleSubmitting ? null : _signInWithGoogle,
                  icon: _isGoogleSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const _GoogleLogo(),
                  label: Text(s(context).continueWithGoogle),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(s(context).orDivider, style: theme.textTheme.labelSmall),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
              const SizedBox(height: 20),
              if (_isSignUp) ...[
                _buildField(theme, controller: _nameController, hint: s(context).nameHint, icon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
              ],
              _buildField(
                theme,
                controller: _emailController,
                hint: s(context).emailHint,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildField(
                theme,
                controller: _passwordController,
                hint: s(context).passwordHint,
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignUp ? s(context).signUpButton : s(context).signInButton),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                  child: Text(
                    _isSignUp ? s(context).haveAccountToggle : s(context).noAccountToggle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    ThemeData theme, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Лого Google без внешнего SVG-ассета: 4 сектора кольца в фирменных цветах.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-90, 90, const Color(0xFF4285F4)); // синий
    arc(0, 90, const Color(0xFF34A853)); // зелёный
    arc(90, 90, const Color(0xFFFBBC05)); // жёлтый
    arc(180, 90, const Color(0xFFEA4335)); // красный

    // горизонтальная перекладина "G"
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth / 2, radius - strokeWidth * 0.3, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
