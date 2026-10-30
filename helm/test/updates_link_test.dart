import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/about_page.dart';

void main() {
  testWidgets('AboutScreen renders Check for Updates tile', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );

    // Initial render
    await tester.pump();

    // Verify Check for Updates tile exists
    expect(find.text('Check for Updates'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);
    expect(find.text('View EULA'), findsOneWidget);
    expect(find.text('View Privacy Policy'), findsOneWidget);
  });
}

