import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/widgets/audio_waveform_visualizer.dart';

void main() {
  testWidgets('AudioWaveformVisualizer renders default 9 bars', (tester) async {
    final controller = StreamController<double>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AudioWaveformVisualizer(
              amplitudeStream: controller.stream,
              barCount: 9,
            ),
          ),
        ),
      ),
    );

    // AudioWaveformVisualizer creates a Row containing 9 bar Containers
    expect(find.byType(AudioWaveformVisualizer), findsOneWidget);
    final rowFinder = find.descendant(
      of: find.byType(AudioWaveformVisualizer),
      matching: find.byType(Row),
    );
    expect(rowFinder, findsOneWidget);

    final row = tester.widget<Row>(rowFinder);
    expect(row.children.length, equals(9));

    // Send amplitude update
    controller.add(0.75);
    await tester.pump(const Duration(milliseconds: 100));

    controller.close();
  });

  testWidgets('AudioWaveformVisualizer renders custom barCount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AudioWaveformVisualizer(
              barCount: 5,
              height: 32,
            ),
          ),
        ),
      ),
    );

    final rowFinder = find.descendant(
      of: find.byType(AudioWaveformVisualizer),
      matching: find.byType(Row),
    );
    expect(rowFinder, findsOneWidget);

    final row = tester.widget<Row>(rowFinder);
    expect(row.children.length, equals(5));
  });
}
