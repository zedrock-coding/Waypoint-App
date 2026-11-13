import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

void showFeedbackDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const FeedbackDialog(),
  );
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  String _feedbackType = 'General';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metaName = user.userMetadata?['full_name'] as String?;
      if (metaName != null && metaName.trim().isNotEmpty) {
        _nameController.text = metaName.trim();
      } else if (user.email != null) {
        _nameController.text = user.email!.split('@').first.trim();
      }
      if (user.email != null) {
        _emailController.text = user.email!.trim();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final rawMessage = _messageController.text.trim();
    final message = _feedbackType == 'General'
        ? rawMessage
        : '[$_feedbackType] $rawMessage';

    try {
      final client = Supabase.instance.client;
      await client.from('feedback').insert({
        'name': name.isNotEmpty ? name : 'Anonymous',
        'email': email.isNotEmpty ? email : 'no-reply@waypoint.app',
        'message': message,
      });

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppTheme.mint, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Thank you! Your feedback has been received.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to send feedback: $e';
      });
    }
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/9584333692?text=Hi,%20I%20need%20help%20with%20Waypoint');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppTheme.surfaceVariant),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: AppTheme.mint,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Feedback & Support',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Help shape the future of Waypoint',
                              style: AppTheme.monoStyle(
                                fontSize: 10.5,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Feedback Type Selector Chips
                Text(
                  'CATEGORY',
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildTypeChip('General'),
                    const SizedBox(width: 6),
                    _buildTypeChip('Bug Report'),
                    const SizedBox(width: 6),
                    _buildTypeChip('Feature Idea'),
                  ],
                ),

                const SizedBox(height: 16),

                // Name Field
                Text(
                  'YOUR NAME',
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'e.g. Lakshya Jadhav',
                    hintStyle: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.mint),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Email Field
                Text(
                  'EMAIL ADDRESS',
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.mint),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Message Field
                Text(
                  'MESSAGE / SUGGESTION',
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your message or suggestion';
                    }
                    return null;
                  },
                  style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Describe what happened or what improvement you would love to see...',
                    hintStyle: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.mint),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.priorityUrgent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.priorityUrgent),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.priorityUrgent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.priorityUrgent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppTheme.priorityUrgent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.priorityUrgent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mint,
                      foregroundColor: AppTheme.onMint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onMint),
                          )
                        : const Text(
                            'SUBMIT FEEDBACK',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // Urgent WhatsApp Support Link
                Center(
                  child: InkWell(
                    onTap: _openWhatsApp,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headset_mic_outlined, size: 13, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            'Need urgent support? Chat on WhatsApp',
                            style: AppTheme.monoStyle(
                              fontSize: 10.5,
                              color: AppTheme.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    final isSelected = _feedbackType == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _feedbackType = label),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? AppTheme.mint : AppTheme.surfaceVariant,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.mint : AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
