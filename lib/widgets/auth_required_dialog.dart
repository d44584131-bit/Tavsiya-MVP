import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../screens/auth/auth_screen.dart';
import '../supabase_service.dart';

/// Проверяет, что пользователь авторизован, прежде чем дать выполнить
/// действие (оставить отзыв, сохранить место). Если нет — сначала
/// показывает предупреждение с объяснением и ссылкой на регистрацию/вход,
/// а не сразу перекидывает на экран входа. Возвращает true, если после
/// диалога (и, если нужно, экрана входа) пользователь авторизован.
Future<bool> ensureAuthenticated(BuildContext context, String action) async {
  if (SupabaseService.currentUser != null) return true;

  final shouldSignIn = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s(context).authRequiredTitle),
      content: Text(s(context).authRequiredMessage(action)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s(context).cancelButton)),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s(context).signInButton)),
      ],
    ),
  );
  if (shouldSignIn != true || !context.mounted) return false;

  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  return SupabaseService.currentUser != null;
}
