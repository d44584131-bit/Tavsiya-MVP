import 'package:flutter/material.dart';
import '../profile/profile_screen.dart'; // AppLanguage enum

class LanguageSelectScreen extends StatelessWidget {
  final ValueChanged<AppLanguage> onSelected;
  const LanguageSelectScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.language_rounded,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('Выберите язык / Tilni tanlang',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              _LangButton(
                  label: 'Русский', onTap: () => onSelected(AppLanguage.ru)),
              const SizedBox(height: 12),
              _LangButton(
                  label: "O'zbekcha", onTap: () => onSelected(AppLanguage.uz)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LangButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
