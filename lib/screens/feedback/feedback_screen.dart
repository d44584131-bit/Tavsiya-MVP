import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../services/feedback_service.dart';
import '../../supabase_service.dart';
import '../../widgets/chip_selector.dart';

/// Форма "Жалобы и предложения" в настройках профиля. Сообщение уходит
/// на сервер и пересылается администратору в Telegram (см. FeedbackService).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  String _category = _categoryKeys.first; // 'complaint' | 'suggestion'
  bool _isSubmitting = false;
  String? _error;

  static const _categoryKeys = ['complaint', 'suggestion'];

  String _categoryLabel(String key) => key == 'complaint' ? s(context).complaintOption : s(context).suggestionOption;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final user = SupabaseService.currentUser;
      await FeedbackService.submit(
        message: text,
        category: _category,
        userEmail: user?.email,
        userName: user?.userMetadata?['display_name'] as String?,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).feedbackSentSnackbar)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s(context).feedbackSendError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s(context).feedbackButton)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s(context).feedbackIntro,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ChipSelector(
                label: s(context).feedbackTypeLabel,
                options: _categoryKeys.map(_categoryLabel).toList(),
                selected: _categoryLabel(_category),
                onSelected: (label) => setState(() => _category = _categoryKeys.firstWhere((k) => _categoryLabel(k) == label)),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: s(context).messageHint,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _controller.text.trim().isEmpty || _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s(context).sendButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
