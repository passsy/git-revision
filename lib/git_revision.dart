import 'dart:async';
import 'dart:io';

import 'package:git_revision/git/git_commands.dart';
import 'package:git_revision/util/process_utils.dart';

class GitVersionerConfig {
  String baseBranch;
  String repoPath;
  int yearFactor;
  int stopDebounce;

  GitVersionerConfig(this.baseBranch, this.repoPath, this.yearFactor, this.stopDebounce)
      : assert(baseBranch != null),
        assert(yearFactor >= 0),
        assert(stopDebounce >= 0);
}

const Duration _YEAR = const Duration(days: 365);

class GitVersioner {
  final GitVersionerConfig config;

  /// always returns a version which automatically caches
  factory GitVersioner(GitVersionerConfig config) {
    return new _CachedGitVersioner(config);
  }

  GitVersioner._(this.config);

  Future<int> get revision async {
    var commits = await baseBranchCommits;
    var timeComponent = await baseBranchTimeComponent;
    return commits.length + timeComponent;
  }

  Future<String> git(String args, {bool onErrorNull = false, bool emptyResultIsError = true}) async {
    var argList = args.split(' ');
    var stdoutFunction = onErrorNull ? stdoutTextOrNull : stdoutText;
    var text = stdoutFunction(await Process.run('git', argList, workingDirectory: config?.repoPath));
    text = text?.trim();
    if (emptyResultIsError) {
      if (text == null || text.isEmpty) {
        throw new ProcessException('git', argList, "returned nothing");
      }
    }
    return text;
  }

  Future<LocalChanges> get localChanges async {
    var changes = await git('diff --shortstat HEAD', emptyResultIsError: false);
    return _parseDiffShortStat(changes);
  }

  Future<String> get versionName async {
    var rev = await revision;
    var branch = await headBranchName ?? await headSha1;
    var changes = await localChanges;
    var dirty = (changes == LocalChanges.NONE) ? '' : '-dirty';

    if (branch == config.baseBranch) {
      return "$rev$dirty";
    } else {
      var additionalCommits = await featureBranchCommits;
      return "${rev}_$branch+${additionalCommits.length}$dirty";
    }
  }

  Future<String> get headBranchName async {
    var name = await git('symbolic-ref --short -q HEAD', onErrorNull: true, emptyResultIsError: false);
    if (name == null) return null;

    // empty branch names can't exits this means no branch name
    if (name.isEmpty) return null;

    assert(() {
      if (name.split('\n').length != 1) throw new ArgumentError("branch name is multiline '$name'");
      return true;
    }());
    return name;
  }

  Future<String> get headSha1 async {
    var hash = await git('rev-parse HEAD');
    assert(() {
      if (hash.isEmpty) throw new ArgumentError("sha1 is empty ''");
      if (hash.split('\n').length != 1) throw new ArgumentError("sha1 is multiline '$hash'");
      return true;
    }());

    return hash;
  }

  /// All first-parent commits in baseBranch
  ///
  /// Most often a subset of [firstHeadBranchCommits]
  Future<List<Commit>> get firstBaseBranchCommits async {
    var base = await baseBranch;
    var commits = await revList('$base', firstParentOnly: true);
    return commits;
  }

  /// All commits in HEAD
  ///
  /// If HEAD is branched off baseBranch it should contain all commits in [firstBaseBranchCommits]
  Future<List<Commit>> get headCommits => revList('HEAD');

  /// Commit where the featureBranch branched off the baseBranch
  Future<Commit> get featureBranchOrigin async {
    var firstBaseCommits = await firstBaseBranchCommits;
    var allheadCommits = await headCommits;

    return allheadCommits.firstWhere((c) => firstBaseCommits.contains(c));
  }

  /// All commits in baseBranch which are also in history of HEAD
  ///
  /// ignores when current branch is merged into baseBranch in the future. Starts from this commit, first finds
  /// where this branch was branched off the base branch and counts the baseBranch commits from there
  Future<List<Commit>> get baseBranchCommits => featureBranchOrigin.then((commit) => revList(commit.sha1));

  /// All commits since HEAD branched off the base branch
  ///
  /// This are the commits which are added to this branch which are not yet merged into baseBranch at this point.
  /// They may be merged already in the future history which will be ignored here
  Future<List<Commit>> get featureBranchCommits async {
    var origin = await featureBranchOrigin;
    return revList('HEAD...${origin.sha1}');
  }

  // TODO check if always valid to use `.first`
  // Then replace all config.baseBranch with await baseBranch
  Future<String> get baseBranch => _branchLocalOrRemote(config.baseBranch).first;

  /// runs `git rev-list $rev` and returns the commits in order new -> old
  Future<List<Commit>> revList(String rev, {bool firstParentOnly = false}) async {
    // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
    String result =
        await git('rev-list --pretty=%cI%n${firstParentOnly ? ' --first-parent' : ''} $rev', emptyResultIsError: false);
    return result.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
      var lines = rawCommit.split('\n');
      return new Commit(lines[0].replaceFirst('commit ', ''), DateTime.parse(lines[1]));
    }).toList(growable: false);
  }

  Future<int> get baseBranchTimeComponent => baseBranchCommits.then(_timeComponent);

  Future<int> get featureBranchTimeComponent => featureBranchCommits.then(_timeComponent);

  int _timeComponent(List<Commit> commits) {
    assert(commits != null);
    if (commits.isEmpty) return 0;

    var completeTime = commits.last.date.difference(commits.first.date).abs();
    if (completeTime == Duration.zero) return 0;

    var completeTimeComponent = _yearFactor(completeTime);

    // find gaps
    var gaps = Duration.zero;
    for (var i = 1; i < commits.length; i++) {
      var prev = commits[i];
      // rev-list comes in reversed order
      var next = commits[i - 1];
      var diff = next.date.difference(prev.date).abs();
      if (diff.inHours >= config.stopDebounce) {
        gaps += diff;
      }
    }

    var gapTimeComponent = _yearFactor(gaps);
    var timeComponent = completeTimeComponent - gapTimeComponent;

    return timeComponent;
  }

  int _yearFactor(Duration duration) => (duration.inSeconds * config.yearFactor / _YEAR.inSeconds + 0.5).toInt();

  /// returns a Stream of branchNames with prepended remotes where [branchName] exists
  ///
  /// `git branch --all --list "*$rev"`
  Stream<String> _branchLocalOrRemote(String branchName) async* {
    var text = await git("branch --all --list *$branchName");
    var branches = text
        .split('\n')
        // remove asterisk marking the current branch
        .map((it) => it.replaceFirst("* ", ""))
        .map((it) => it.trim());

    for (var branch in branches) {
      yield branch;
    }
  }
}

/// parses the output of `git diff --shortstat`
/// https://github.com/git/git/blob/69e6b9b4f4a91ce90f2c38ed2fa89686f8aff44f/diff.c#L1561
LocalChanges _parseDiffShortStat(String text) {
  if (text == null || text.isEmpty) return LocalChanges.NONE;
  var parts = text.split(",").map((it) => it.trim());

  var filesChanges = 0;
  var additions = 0;
  var deletions = 0;

  for (final part in parts) {
    if (part.contains("changed")) {
      filesChanges = _startingNumber(part) ?? 0;
    }
    if (part.contains("(+)")) {
      additions = _startingNumber(part) ?? 0;
    }
    if (part.contains("(-)")) {
      deletions = _startingNumber(part) ?? 0;
    }
  }
  return new LocalChanges(filesChanges, additions, deletions);
}

final _numberRegEx = new RegExp("(\\d+).*");

/// returns the int of a string it starts with
int _startingNumber(String text) {
  var match = _numberRegEx.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return int.parse(match.group(1));
  }
  return null;
}

const bool ANALYZE_TIME = false;

/// Caching layer for [GitVersioner]. Caches all futures which never produce a different result (if git repo doesn't change)
class _CachedGitVersioner extends GitVersioner {
  _CachedGitVersioner(GitVersionerConfig config) : super._(config);

  var _indent = 0;
  final Map<String, Future> _futureCache = {};

  /// Caches futures
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
      var start = new DateTime.now();
      _indent++;
      var indent = _indent;

      if (!io) {
        for (var i = 1; i < indent; i++) stdout.write("| ");
        print("+ '$name'");
      }

      var result = await future;
      _indent--;
      var diff = new DateTime.now().difference(start);

      for (var i = 1; i < indent; i++) stdout.write("| ");
      print("${io ? '>' : '=>'} '$name' took ${diff.inMilliseconds}ms");
      return result;
    } else {
      return await future;
    }
  }

  @override
  Future<int> get revision => cache(() => super.revision, 'revision');

  @override
  Future<int> get featureBranchTimeComponent =>
      cache(() => super.featureBranchTimeComponent, '<featureBranch> timeComponent');

  @override
  Future<int> get baseBranchTimeComponent => cache(() => super.baseBranchTimeComponent, '<baseBranch> timeComponent');

  @override
  Future<List<Commit>> get firstBaseBranchCommits =>
      cache(() => super.firstBaseBranchCommits, 'firstBaseBranchCommits');

  @override
  Future<List<Commit>> get featureBranchCommits => cache(() => super.featureBranchCommits, '<featureBranch> commits');

  @override
  Future<List<Commit>> get baseBranchCommits => cache(() => super.baseBranchCommits, '<baseBranch> commits');

  @override
  Future<String> get headSha1 => cache(() => super.headSha1, 'rev-parse HEAD', io: true);

  @override
  Future<String> get headBranchName => cache(() => super.headBranchName, 'symbolic-ref --short -q HEAD', io: true);

  @override
  Future<String> get versionName => cache(() => super.versionName, 'versionName');

  @override
  Future<LocalChanges> get localChanges => cache(() => super.localChanges, 'diff --shortstat HEAD', io: true);

  @override
  Future<List<Commit>> revList(String rev, {bool firstParentOnly = false}) => cache(
      () => super.revList(rev, firstParentOnly: firstParentOnly),
      'rev-list $rev${firstParentOnly ? ' --first-parent' : ''}',
      io: true);

  @override
  Future<List<Commit>> get headCommits => cache(() => super.headCommits, 'headCommits');

  @override
  Future<String> get baseBranch => cache(() => super.baseBranch, 'branch --all --list', io: true);

  @override
  Future<Commit> get featureBranchOrigin => cache(() => super.featureBranchOrigin, 'featureBranchOrigin');
}
