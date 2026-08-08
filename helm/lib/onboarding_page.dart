import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildSlide(_slides[index]);
            },
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
                
                // Call to Action
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _currentPage == _slides.length - 1 ? 1.0 : 0.0,
                  child: _currentPage == _slides.length - 1
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(height: 56),
                ),
              ],
            ),
          ),
        ],
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
          Icon(
            slide.icon,
            size: 120,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 60),
          Text(
            slide.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            slide.subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100), // Space for bottom controls
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
        color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
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
