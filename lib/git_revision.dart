import 'dart:async';
import 'dart:io';

import 'package:git_revision/git/commit.dart';
import 'package:git_revision/git/local_changes.dart';

const Duration _YEAR = const Duration(days: 365);

class GitVersioner {
  static const String DEFAULT_BRANCH = 'master';
  static const int DEFAULT_YEAR_FACTOR = 1000;
  static const int DEFAULT_STOP_DEBOUNCE = 48;

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

  Future<String> git(String args, {bool emptyResultIsError = true}) async {
    var argList = args.split(' ');

    final processResult = await Process.run('git', argList, workingDirectory: config?.repoPath);
    if (processResult.exitCode != 0) {
      return null;
    }
    var text = processResult.stdout as String;
    text = text?.trim();
    if (emptyResultIsError) {
      if (text == null || text.isEmpty) {
        throw new ProcessException('git', argList, "returned nothing");
      }
    }
    return text;
  }

  Future<LocalChanges> get localChanges async {
    if (config.rev != 'HEAD') {
      // local changes are only interesting for HEAD during active development
      return LocalChanges.NONE;
    }

    var changes = await git('diff --shortstat HEAD', emptyResultIsError: false);
    if (changes == null) return null;
    return _parseDiffShortStat(changes);
  }

  // TODO swap name with revision
  Future<String> get versionName async {
    var rev = await revision;
    var hash = (await sha1)?.substring(0, 7) ?? "0000000";
    var additionalCommits = await featureBranchCommits;

    if (config.rev == 'HEAD') {
      var branch = await headBranchName;
      var changes = await localChanges;

      String name = '';
      if (branch != null && branch != config.baseBranch) {
        name = branch != null ? "_$branch" : '';
      }
      if (config.name != null && config.name != config.baseBranch) {
        name = "_${config.name}";
      }
      var furtherPart = additionalCommits.isNotEmpty ? "+${additionalCommits.length}" : '';
      var dirtyPart = (changes == LocalChanges.NONE) ? '' : '-dirty';

      return "$rev$name${furtherPart}_$hash$dirtyPart";
    } else {
      var furtherPart = additionalCommits.isNotEmpty ? "+${additionalCommits.length}" : '';
      String name = '';

      if (!hash.startsWith(config.rev) && config.rev != config.baseBranch) {
        name = "_${config.rev}";
      }
      if (config.name != null && config.name != config.baseBranch) {
        name = "_${config.name}";
      }

      return "$rev$name${furtherPart}_$hash";
    }
  }

  Future<String> get headBranchName async {
    var name = await git('symbolic-ref --short -q HEAD', emptyResultIsError: false);
    if (name == null) return null;

    // empty branch names can't exits this means no branch name
    if (name.isEmpty) return null;

    assert(() {
      if (name.split('\n').length != 1) throw new ArgumentError("branch name is multiline '$name'");
      return true;
    }());
    return name;
  }

  /// full Sha1 or `null`
  Future<String> get sha1 async {
    var hash = await git('rev-parse ${config.rev}', emptyResultIsError: false);
    if (hash == null) {
      return null;
    }
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
  Future<List<Commit>> get allFirstBaseBranchCommits async {
    try {
      var base = await _branchLocalOrRemote(config.baseBranch).first;
      var commits = await revList('$base', firstParentOnly: true);
      return commits;
    } catch (ex, stack) {
      return [];
    }
  }

  /// All commits in history of [GitVersionerConfig.rev]
  Future<List<Commit>> get commits => revList(config.rev);

  /// Commit where the featureBranch branched off the baseBranch or the first commit in history in case of an
  /// unrelated history
  Future<Commit> get featureBranchOrigin async {
    var firstBaseCommits = await allFirstBaseBranchCommits;
    var allheadCommits = await commits;

    try {
      return allheadCommits.firstWhere((c) => firstBaseCommits.contains(c));
    } catch (ex, stack) {
      return null;
    }
  }

  /// All commits in baseBranch which are also in history of [GitVersionerConfig.rev]
  ///
  /// ignores when current branch is merged into baseBranch in the future. Starts from this commit, first finds
  /// where this branch was branched off the base branch and counts the baseBranch commits from there
  Future<List<Commit>> get baseBranchCommits =>
      featureBranchOrigin.then((commit) => revList(commit.sha1)).catchError((ex, stack) => []);

  /// All commits since [GitVersionerConfig.rev] branched off the base branch
  ///
  /// This are the commits which are added to this branch which are not yet merged into baseBranch at this point.
  /// They may be merged already in the future history which will be ignored here
  Future<List<Commit>> get featureBranchCommits async {
    var origin = await featureBranchOrigin;
    if(origin != null){
      return revList('${config.rev}...${origin.sha1}');
    } else {
      // in case of unrelated histories use all commit in history
      return await commits;
    }
  }

  /// runs `git rev-list $rev` and returns the commits in order new -> old
  Future<List<Commit>> revList(String rev, {bool firstParentOnly = false}) async {
    // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
    String result =
        await git('rev-list --pretty=%cI%n${firstParentOnly ? ' --first-parent' : ''} $rev', emptyResultIsError: false);
    if (result == null) return [];

    return result.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
      var lines = rawCommit.split('\n');
      return new Commit(lines[0].replaceFirst('commit ', ''), lines[1]);
    }).toList(growable: false);
  }

  Future<int> get baseBranchTimeComponent => baseBranchCommits.then(_timeComponent);

  Future<int> get featureBranchTimeComponent => featureBranchCommits.then(_timeComponent);

  int _timeComponent(List<Commit> commits) {
    assert(commits != null);
    if (commits.isEmpty) return 0;

    var completeTime = commits.last.date.difference(commits.first.date).abs();
    if (completeTime == Duration.zero) return 0;

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

    // remove huge gaps where no work happened
    var workingTime = completeTime - gaps;
    var timeComponent = _yearFactor(workingTime);

    return timeComponent;
  }

  int _yearFactor(Duration duration) => (duration.inSeconds * config.yearFactor / _YEAR.inSeconds + 0.5).toInt();

  /// returns a Stream of branchNames with prepended remotes where [branchName] exists
  ///
  /// `git branch --all --list "*$rev"`
  Stream<String> _branchLocalOrRemote(String branchName) async* {
    String text = await git("branch --all --list *$branchName");
    if (text == null) {
      return;
    }
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
  Future<List<Commit>> get allFirstBaseBranchCommits =>
      cache(() => super.allFirstBaseBranchCommits, 'allFirstBaseBranchCommits');

  @override
  Future<List<Commit>> get featureBranchCommits => cache(() => super.featureBranchCommits, '<featureBranch> commits');

  @override
  Future<List<Commit>> get baseBranchCommits => cache(() => super.baseBranchCommits, '<baseBranch> commits');

  @override
  Future<String> get sha1 => cache(() => super.sha1, 'rev-parse ${config.rev}', io: true);

  @override
  Future<String> get headBranchName =>
      cache(() => super.headBranchName, 'symbolic-ref --short -q ${config.rev}', io: true);

  @override
  Future<String> get versionName => cache(() => super.versionName, 'versionName');

  @override
  Future<LocalChanges> get localChanges => cache(() => super.localChanges, 'diff --shortstat ${config.rev}', io: true);

  @override
  Future<List<Commit>> revList(String rev, {bool firstParentOnly = false}) => cache(
      () => super.revList(rev, firstParentOnly: firstParentOnly),
      'rev-list $rev${firstParentOnly ? ' --first-parent' : ''}',
      io: true);

  @override
  Future<List<Commit>> get commits => cache(() => super.commits, 'commits');

  @override
  Future<Commit> get featureBranchOrigin => cache(() => super.featureBranchOrigin, 'featureBranchOrigin');
}

class GitVersionerConfig {
  String baseBranch;
  String repoPath;
  int yearFactor;
  int stopDebounce;
  String name;

  /// The revision for which the version should be calculated
  String rev;

  GitVersionerConfig(this.baseBranch, this.repoPath, this.yearFactor, this.stopDebounce, this.name, this.rev)
      : assert(baseBranch != null),
        assert(yearFactor >= 0),
        assert(stopDebounce >= 0),
        assert(rev != null && rev.isNotEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitVersionerConfig &&
          runtimeType == other.runtimeType &&
          baseBranch == other.baseBranch &&
          repoPath == other.repoPath &&
          yearFactor == other.yearFactor &&
          stopDebounce == other.stopDebounce &&
          name == other.name &&
          rev == other.rev;

  @override
  int get hashCode =>
      baseBranch.hashCode ^
      repoPath.hashCode ^
      yearFactor.hashCode ^
      stopDebounce.hashCode ^
      name.hashCode ^
      rev.hashCode;
}
