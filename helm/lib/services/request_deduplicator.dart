import 'dart:async';

/// Deduplicates and coalesces concurrent in-flight asynchronous operations.
/// Prevents duplicate GET/RPC roundtrips across concurrent components (Video 3 Technique 3).
class RequestDeduplicator {
  static final RequestDeduplicator instance = RequestDeduplicator();

  final Map<String, Future<dynamic>> _inFlight = {};

  /// Runs [action] if no matching request for [key] is currently in-flight.
  /// If a request for [key] is already executing, joins the existing Future.
  Future<T> run<T>(String key, Future<T> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    final future = action();
    _inFlight[key] = future;

    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Checks if a request for [key] is currently executing.
  bool isInFlight(String key) => _inFlight.containsKey(key);

  /// Count of active in-flight operations.
  int get inFlightCount => _inFlight.length;

  /// Clear all tracking.
  void clear() {
    _inFlight.clear();
  }
}
