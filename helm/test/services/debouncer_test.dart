import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/debouncer.dart';

void main() {
  group('Debouncer (Video 3 Technique 4: Debounce Inputs)', () {
    late Debouncer debouncer;

    setUp(() {
      debouncer = Debouncer(milliseconds: 100);
    });

    tearDown(() {
      debouncer.dispose();
    });

    test('debounces rapid calls and only triggers the last one', () async {
      int callCount = 0;
      int lastValue = 0;

      for (int i = 1; i <= 5; i++) {
        final val = i;
        debouncer.run(() {
          callCount++;
          lastValue = val;
        });
      }

      expect(debouncer.isActive, isTrue);
      expect(callCount, equals(0));

      // Wait past the debounce duration
      await Future.delayed(const Duration(milliseconds: 150));

      expect(debouncer.isActive, isFalse);
      expect(callCount, equals(1));
      expect(lastValue, equals(5));
    });

    test('cancelling debouncer prevents pending execution', () async {
      bool executed = false;

      debouncer.run(() {
        executed = true;
      });

      expect(debouncer.isActive, isTrue);
      debouncer.cancel();
      expect(debouncer.isActive, isFalse);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executed, isFalse);
    });
  });
}
