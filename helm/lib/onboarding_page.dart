import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    const OnboardingSlide(
      icon: Icons.space_dashboard_outlined,
      title: "Welcome to Helm",
      subtitle: "Navigate your tasks seamlessly.",
    ),
    const OnboardingSlide(
      icon: Icons.mic_none,
      title: "Say the word",
      subtitle: "Tap the mic to create tasks instantly with AI voice commands.",
    ),
    const OnboardingSlide(
      icon: Icons.swipe_outlined,
      title: "Total control",
      subtitle: "Swipe to complete, drag to prioritize.",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await context.read<ThemeProvider>().completeOnboarding();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): const NextSlideIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const PreviousSlideIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const NextSlideIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NextSlideIntent: CallbackAction<NextSlideIntent>(onInvoke: (_) => _nextPage()),
          PreviousSlideIntent: CallbackAction<PreviousSlideIntent>(onInvoke: (_) => _previousPage()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            body: Stack(
              children: [
                // Background Glow
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus},
                  ),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) => _buildSlide(_slides[index]),
                  ),
                ),

                // Top Controls (Skip)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          "Skip Tutorial",
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom Controls
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => _buildIndicator(index == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // CTA Button Group with Back & Next
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          children: [
                            if (_currentPage > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _previousPage,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Back'),
                                ),
                              ),
                            if (_currentPage > 0) const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _nextPage,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide.icon,
              size: 100,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 60),
          Text(
            slide.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            slide.subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class NextSlideIntent extends Intent {
  const NextSlideIntent();
}

class PreviousSlideIntent extends Intent {
  const PreviousSlideIntent();
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
