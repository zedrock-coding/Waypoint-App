import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/core/ui/responsive_clamp.dart';

void main() {
  group('UIClamp Math & Bounds Tests', () {
    test('value clamps raw double correctly', () {
      expect(UIClamp.value(5.0, 10.0, 20.0), 10.0);
      expect(UIClamp.value(15.0, 10.0, 20.0), 15.0);
      expect(UIClamp.value(25.0, 10.0, 20.0), 20.0);
    });

    testWidgets('clamp scales dimension proportionally with screen width',
        (tester) async {
      late double calculatedCompact;
      late double calculatedExpanded;

      // 1. Compact screen: 320px width (baseline = 390)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              calculatedCompact = context.clampDimension(
                min: 12.0,
                preferred: 20.0,
                max: 30.0,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // (20 * 320 / 390) = ~16.41, which is within [12, 30]
      expect(calculatedCompact, closeTo(16.41, 0.1));

      // 2. Large tablet/desktop screen: 1200px width
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              calculatedExpanded = context.clampDimension(
                min: 12.0,
                preferred: 20.0,
                max: 30.0,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // (20 * 1200 / 390) = ~61.5 -> Clamped to max 30.0!
      expect(calculatedExpanded, 30.0);
    });

    testWidgets('formFactor identifies compact, medium, and expanded displays',
        (tester) async {
      late FormFactor factor;

      // Phone (< 600)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              factor = context.formFactor;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(factor, FormFactor.compact);

      // Tablet / Foldable (600 - 839)
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              factor = context.formFactor;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(factor, FormFactor.medium);

      // Desktop / Web (>= 840)
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              factor = context.formFactor;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(factor, FormFactor.expanded);
    });

    testWidgets('responsive helper selects value based on form factor',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late int columns;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              columns = context.responsive<int>(
                compact: 1,
                medium: 2,
                expanded: 4,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(columns, 1);

      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              columns = context.responsive<int>(
                compact: 1,
                medium: 2,
                expanded: 4,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(columns, 2);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              columns = context.responsive<int>(
                compact: 1,
                medium: 2,
                expanded: 4,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(columns, 4);
    });

    testWidgets('clampedTextScaler bounds extreme font sizes to prevent overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final normal = UIClamp.clampedTextScaler(context, userScale: 1.0);
              expect(normal.scale(14), 14.0);

              final excessive = UIClamp.clampedTextScaler(
                context,
                userScale: 2.5,
              );
              // Clamped to 1.25 max
              expect(excessive.scale(14), 14 * 1.25);

              final undersized = UIClamp.clampedTextScaler(
                context,
                userScale: 0.4,
              );
              // Clamped to 0.85 min
              expect(undersized.scale(14), 14 * 0.85);

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('Zero Overflow Stress Tests on Small Devices', () {
    testWidgets('renders dense header content on small 320px phone without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568); // iPhone SE 1st gen size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.clampDimension(
                      min: 8,
                      preferred: 16,
                      max: 24,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Community Workspace Long Title',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.mic, size: 20),
                              SizedBox(width: 4),
                              Icon(Icons.search, size: 20),
                              SizedBox(width: 4),
                              Icon(Icons.notifications, size: 20),
                              SizedBox(width: 4),
                              CircleAvatar(radius: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify no exceptions or overflow occurred
      expect(tester.takeException(), isNull);
    });
  });
}
