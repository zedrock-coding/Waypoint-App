import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helm/widgets/app_snackbar.dart';

void main() {
  testWidgets('AppSnackBar.showUndo renders pill snackbar and triggers callback', (
    tester,
  ) async {
    bool undoCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppSnackBar.showUndo(
                    context: context,
                    message: 'Task deleted',
                    onUndo: () => undoCalled = true,
                  );
                },
                child: const Text('Show'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to show snackbar
    await tester.tap(find.text('Show'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Complete entry animation

    // Verify message and action
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.width, 310);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, const Color(0xFF222528));
    expect(snackBar.duration, const Duration(seconds: 5));

    // Tap UNDO
    await tester.tap(find.text('UNDO'));
    await tester.pump();
    expect(undoCalled, isTrue);
  });
}

