import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/request_deduplicator.dart';

void main() {
  group('RequestDeduplicator (Video 3 Technique 3: Deduplicate API Calls)', () {
    late RequestDeduplicator deduplicator;

    setUp(() {
      deduplicator = RequestDeduplicator();
    });

    test('coalesces concurrent requests for identical key into single future', () async {
      int executionCount = 0;

      Future<String> worker() async {
        executionCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success';
      }

      // Fire 3 simultaneous concurrent calls
      final futures = Future.wait<String>([
        deduplicator.run<String>('test_key', worker),
        deduplicator.run<String>('test_key', worker),
        deduplicator.run<String>('test_key', worker),
      ]);

      expect(deduplicator.isInFlight('test_key'), isTrue);
      expect(deduplicator.inFlightCount, equals(1));

      final results = await futures;

      expect(results, equals(['success', 'success', 'success']));
      expect(executionCount, equals(1), reason: 'Only 1 execution must occur across concurrent callers');
      expect(deduplicator.isInFlight('test_key'), isFalse);
      expect(deduplicator.inFlightCount, equals(0));
    });

    test('subsequent calls after completion trigger fresh execution', () async {
      int executionCount = 0;

      Future<int> worker() async {
        executionCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return executionCount;
      }

      final first = await deduplicator.run<int>('seq_key', worker);
      expect(first, equals(1));

      final second = await deduplicator.run<int>('seq_key', worker);
      expect(second, equals(2));
      expect(executionCount, equals(2));
    });

    test('propagates errors to all concurrent callers and clears in-flight state', () async {
      int executionCount = 0;

      Future<String> failingWorker() async {
        executionCount++;
        await Future.delayed(const Duration(milliseconds: 20));
        throw Exception('Network timeout');
      }

      final f1 = deduplicator.run<String>('error_key', failingWorker);
      final f2 = deduplicator.run<String>('error_key', failingWorker);

      await Future.wait([
        expectLater(f1, throwsA(isA<Exception>())),
        expectLater(f2, throwsA(isA<Exception>())),
      ]);

      expect(executionCount, equals(1));
      expect(deduplicator.isInFlight('error_key'), isFalse);
    });
  });
}
