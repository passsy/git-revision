import 'dart:async';

const bool analyze = false;

// Mixin allowing to cache Futures
class FutureCacheMixin {
  final Map<String, Future> _futureCache = {};

  /// Caches futures
  /// [key] cacheKey
  Future<T> cache<T>(Future<T> Function() futureProvider, String key) async {
    final cached = _futureCache[key] as Future<T>?;
    Future<T> future;
    if (cached != null) {
      future = cached;
    } else {
      future = futureProvider();
      _futureCache[key] = future;
    }

    if (analyze) {
      if (cached == null) {
        print("       > $key");
        final start = DateTime.now();
        final result = await future;
        final diff = DateTime.now().difference(start);
        print("${diff.inMilliseconds.toString().padLeft(4)}ms < $key");
        return result;
      } else {
        print("       - $key");
      }
    }

    return future;
  }
}
