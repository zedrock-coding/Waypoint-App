import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic sanity smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Helm App'),
          ),
        ),
      ),
    );

    expect(find.text('Helm App'), findsOneWidget);
  });
}
