import 'dart:async';

const bool ANALYZE = false;

// Mixin allowing to cache Futures
class FutureCacheMixin {
  final Map<String, Future> _futureCache = {};

  /// Caches futures
  /// [key] cacheKey
  Future<T> cache<T>(Future<T> futureProvider(), String key) async {
    var cached = _futureCache[key];
    Future<T> future;
    if (cached != null) {
      future = cached;
    } else {
      future = futureProvider();
      _futureCache[key] = future;
    }

    if (ANALYZE) {
      if (cached == null) {
        print("       > $key");
        var start = DateTime.now();
        var result = await future;
        var diff = DateTime.now().difference(start);
        print("${diff.inMilliseconds.toString().padLeft(4)}ms < $key");
        return result;
      } else {
        print("       - $key");
      }
    }

    return future;
  }
}
