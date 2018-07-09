part of 'git_revision.dart';

const bool ANALYZE_TIME = false;

/// Caching layer for [GitVersioner]. Caches all futures which never produce a different result (if git repo doesn't change)
class _CachedGitVersioner implements GitVersioner {
  GitVersioner _delegate;

  _CachedGitVersioner(GitVersioner delegate) : _delegate = delegate;

  var _indent = 0;
  final Map<String, Future> _futureCache = {};

  /// Caches futures
  /// [io] true when communication with `git` is required
  Future<T> cache<T>(Future<T> futureProvider(), String name, {bool io = false}) async {
    var cached = _futureCache[name];
    if (cached != null) {
      if (ANALYZE_TIME) {
        for (var i = 0; i < _indent; i++) stdout.write("| ");
        print(">>>> cache hit '$name'");
      }
      return cached;
    }
    var future = futureProvider();
    _futureCache[name] = future;

    if (ANALYZE_TIME) {
      return _analyzedTime(future, name, io);
    }
    return future;
  }

  Future<T> _analyzedTime<T>(Future<T> future, String loggingName, bool ioRequest) async {
    var start = new DateTime.now();
    _indent++;
    var indent = _indent;

    if (!ioRequest) {
      for (var i = 1; i < indent; i++) stdout.write("| ");
      print("+ '$loggingName'");
    }

    var result = await future;
    _indent--;
    var diff = new DateTime.now().difference(start);

    for (var i = 1; i < indent; i++) stdout.write("| ");
    print("${ioRequest ? '>' : '=>'} '$loggingName' took ${diff.inMilliseconds}ms");
    return result;
  }

  @override
  Future<int> get revision => cache(() => _delegate.revision, 'revision');

  @override
  Future<int> get featureBranchTimeComponent =>
      cache(() => _delegate.featureBranchTimeComponent, '<featureBranch> timeComponent');

  @override
  Future<int> get baseBranchTimeComponent =>
      cache(() => _delegate.baseBranchTimeComponent, '<baseBranch> timeComponent');

  @override
  Future<List<Commit>> get allFirstBaseBranchCommits =>
      cache(() => _delegate.allFirstBaseBranchCommits, 'allFirstBaseBranchCommits');

  @override
  Future<List<Commit>> get featureBranchCommits =>
      cache(() => _delegate.featureBranchCommits, '<featureBranch> commits');

  @override
  Future<List<Commit>> get baseBranchCommits =>
      cache<List<Commit>>(() => _delegate.baseBranchCommits, '<baseBranch> commits');

  @override
  Future<String> get sha1 => cache(() => _delegate.sha1, 'rev-parse ${config.rev}', io: true);

  @override
  Future<String> get headBranchName =>
      cache(() => _delegate.headBranchName, 'symbolic-ref --short -q ${config.rev}', io: true);

  @override
  Future<String> get versionName => cache(() => _delegate.versionName, 'versionName');

  @override
  Future<LocalChanges> get localChanges =>
      cache(() => _delegate.localChanges, 'diff --shortstat ${config.rev}', io: true);

  @override
  Future<List<Commit>> revList(String rev, {bool firstParentOnly = false}) {
    var name = 'rev-list $rev${firstParentOnly ? ' --first-parent' : ''}';
    return cache(() => _delegate.revList(rev, firstParentOnly: firstParentOnly), name, io: true);
  }

  @override
  Future<List<Commit>> get commits => cache(() => _delegate.commits, 'commits');

  @override
  Future<Commit> get featureBranchOrigin => cache(() => _delegate.featureBranchOrigin, 'featureBranchOrigin');

  @override
  GitVersionerConfig get config => _delegate.config;

  @override
  Future<String> git(String args, {bool emptyResultIsError: true}) =>
      _delegate.git(args, emptyResultIsError: emptyResultIsError);

  @override
  Stream<String> _branchLocalOrRemote(String branchName) =>
      throw new Exception("Accessed private function form outside");

  @override
  int _timeComponent(List<Commit> commits) => throw new Exception("Accessed private function form outside");

  @override
  int _yearFactor(Duration duration) => throw new Exception("Accessed private function form outside");
}
