import 'package:flutter/material.dart';

enum AIState { listening, processing, success }

class AIVoiceOverlay extends StatefulWidget {
  const AIVoiceOverlay({super.key});

  @override
  State<AIVoiceOverlay> createState() => _AIVoiceOverlayState();
}

class _AIVoiceOverlayState extends State<AIVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  AIState _currentState = AIState.listening;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Mock transition for demonstration
    _simulateAIWorkflow();
  }

  Future<void> _simulateAIWorkflow() async {
    // Listen for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    setState(() => _currentState = AIState.processing);
    
    // Process for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _currentState = AIState.success);

    // Show success for 1.5 seconds then close
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCenterGraphic(colorScheme),
          const SizedBox(height: 24),
          _buildStatusText(colorScheme),
          const SizedBox(height: 8),
          if (_currentState == AIState.listening)
            Text(
              "Try saying \"Add a task for tomorrow morning\"",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterGraphic(ColorScheme colorScheme) {
    switch (_currentState) {
      case AIState.listening:
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  size: 48,
                  color: Colors.tealAccent,
                ),
              ),
            );
          },
        );
      case AIState.processing:
        return const SizedBox(
          height: 80,
          width: 80,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
        );
      case AIState.success:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Colors.white,
          ),
        );
    }
  }

  Widget _buildStatusText(ColorScheme colorScheme) {
    String text;
    switch (_currentState) {
      case AIState.listening:
        text = "Helm is listening...";
        break;
      case AIState.processing:
        text = "Creating Task...";
        break;
      case AIState.success:
        text = "Task Added Successfully";
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
