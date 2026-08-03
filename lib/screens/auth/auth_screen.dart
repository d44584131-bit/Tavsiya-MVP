import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_service.dart';

/// Экран входа / регистрации. Показывается поверх текущего экрана (push),
/// когда действие требует авторизации (сохранить место, оставить отзыв и т.п.).
/// При успехе сама себя закрывает — вызывающий экран узнаёт об этом
/// через `SupabaseService.authStateChanges` или проверяя `currentUser` после pop.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
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

      if (SupabaseService.currentUser != null) {
        Navigator.of(context).pop();
        return;
      }
      // Регистрация прошла, но требуется подтверждение почты — сессии ещё нет.
      setState(() {
        _isSubmitting = false;
        _isSignUp = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте почту, чтобы подтвердить регистрацию, затем войдите')),
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
        _error = 'Что-то пошло не так. Попробуйте ещё раз';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp ? 'Создать аккаунт' : 'С возвращением',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? 'Регистрация нужна, чтобы оставлять отзывы и сохранять места'
                    : 'Войдите, чтобы оставлять отзывы и сохранять места',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (_isSignUp) ...[
                _buildField(theme, controller: _nameController, hint: 'Ваше имя', icon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
              ],
              _buildField(
                theme,
                controller: _emailController,
                hint: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildField(
                theme,
                controller: _passwordController,
                hint: 'Пароль (минимум 6 символов)',
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
                      : Text(_isSignUp ? 'Зарегистрироваться' : 'Войти'),
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
                    _isSignUp ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться',
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
