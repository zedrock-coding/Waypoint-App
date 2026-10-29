import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders password sign in view by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('First time here? Sign up with Email OTP'), findsOneWidget);
  });

  testWidgets('AuthScreen switches to Email OTP mode on button tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    final otpButton = find.text('First time here? Sign up with Email OTP');
    await tester.tap(otpButton);
    await tester.pumpAndSettle();

    expect(find.text('First-Time Sign Up'), findsOneWidget);
    expect(find.text('SEND 6-DIGIT CODE'), findsOneWidget);
    expect(find.text('Already have an account? Sign In with Password'), findsOneWidget);
  });

  testWidgets('AuthScreen switches to Forgot Password mode on link tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    final forgotButton = find.text('Forgot password?');
    await tester.tap(forgotButton);
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('SEND RESET CODE'), findsOneWidget);
    expect(find.text('Back to Sign In'), findsOneWidget);
  });
}

