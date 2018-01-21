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

  Future<LocalChanges> get localChanges async {
    var changes = stdoutText(await Process.run('git', ['diff', '--shortstat', 'HEAD'])).trim();
    return _parseDiffShortStat(changes);
  }

  Future<String> get versionName async {
    var rev = await revision;
    var branch = await branchName;
    var changes = await localChanges;
    var dirty = (changes == LocalChanges.NONE) ? '' : '-dirty';

    if (branch == config.baseBranch) {
      return "$rev$dirty";
    } else {
      var additionalCommits = await featureBranchCommits;
      return "${rev}_$branch+${additionalCommits.length}$dirty";
    }
  }

  Future<String> get branchName async {
    var name = stdoutTextOrNull(await Process.run('git', ['symbolic-ref', '--short', '-q', 'HEAD']))?.trim();
    if (name == null) return null;

    // empty branch names can't exits this means no branch name
    if (name.isEmpty) return null;

    assert(() {
      if (name.split('\n').length != 1) throw new ArgumentError("branch name is multiline '$name'");
      return true;
    }());
    return name;
  }

  Future<String> get sha1 async {
    var hash = stdoutText(await Process.run('git', ['rev-parse', 'HEAD'])).trim();

    assert(() {
      if (hash.isEmpty) throw new ArgumentError("sha1 is empty ''");
      if (hash.split('\n').length != 1) throw new ArgumentError("sha1 is multiline '$hash'");
      return true;
    }());

    return hash;
  }

  Future<List<Commit>> get commitsToHead => _revList('HEAD');

  Future<List<Commit>> get baseBranchCommits => mergeBaseHeadBase.then(_revList);

  Future<List<Commit>> get featureBranchCommits => _revList('${config.baseBranch}..HEAD');

  /// root of feature branch from baseBranch
  Future<String> get mergeBaseHeadBase async {
    try {
      return stdoutText(
              await Process.run('git', ['merge-base', 'HEAD', config.baseBranch], workingDirectory: config?.repoPath))
          .trim();
    } catch (e, _) {
      return stdoutText(await Process.run('git', ['merge-base', 'HEAD', "origin/${config.baseBranch}"],
              workingDirectory: config?.repoPath))
          .trim();
    }
  }

  /// runs `git rev-list $rev` and returns the commits in order new -> old
  Future<List<Commit>> _revList(String rev) async {
    // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
    String result;
    try {
      result =
          stdoutText(await Process.run('git', ['rev-list', '--pretty=%cI%n', rev], workingDirectory: config?.repoPath));
    } catch (e, _) {
      result = stdoutText(
          await Process.run('git', ['rev-list', '--pretty=%cI%n', "origin/$rev"], workingDirectory: config?.repoPath));
    }
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
}

/// parses the output of `git diff --shortstat`
/// https://github.com/git/git/blob/69e6b9b4f4a91ce90f2c38ed2fa89686f8aff44f/diff.c#L1561
LocalChanges _parseDiffShortStat(String text) {
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

/// Caching layer for [GitVersioner]. Caches all futures which never produce a different result (if git repo doesn't change)
class _CachedGitVersioner extends GitVersioner {
  _CachedGitVersioner(GitVersionerConfig config) : super._(config);

  Future<int> _revision;

  @override
  Future<int> get revision => _revision ??= time(super.revision, 'revision');

  Future<int> _featureBranchTimeComponent;

  @override
  Future<int> get featureBranchTimeComponent => _featureBranchTimeComponent ??= time(super.featureBranchTimeComponent, 'featureBranchTimeComponent');

  Future<int> _baseBranchTimeComponent;

  @override
  Future<int> get baseBranchTimeComponent => _baseBranchTimeComponent ??= time(super.baseBranchTimeComponent, 'baseBranchTimeComponent');

  Future<String> _mergeBaseHeadBase;

  @override
  Future<String> get mergeBaseHeadBase => _mergeBaseHeadBase ??= time(super.mergeBaseHeadBase, 'mergeBaseHeadBase');

  Future<List<Commit>> _featureBranchCommits;

  @override
  Future<List<Commit>> get featureBranchCommits => _featureBranchCommits ??= time(super.featureBranchCommits, 'featureBranchCommits');

  Future<List<Commit>> _baseBranchCommits;

  @override
  Future<List<Commit>> get baseBranchCommits => _baseBranchCommits ??= time(super.baseBranchCommits, 'baseBranchCommits');

  Future<List<Commit>> _commitsToHead;

  @override
  Future<List<Commit>> get commitsToHead => _commitsToHead ??= time(super.commitsToHead, 'commitsToHead');

  Future<String> _sha1;

  @override
  Future<String> get sha1 => _sha1 ??= time(super.sha1, 'sha1');

  Future<String> _branchName;

  @override
  Future<String> get branchName => _branchName ??= time(super.branchName, 'branchName');

  Future<String> _versionName;

  @override
  Future<String> get versionName => _versionName ??= time(super.versionName, 'versionName');

  Future<LocalChanges> _localChanges;

  @override
  Future<LocalChanges> get localChanges => _localChanges ??= time(super.localChanges, 'localChanges');
}

const bool ANALYZE_TIME = false;

Future<T> time<T>(Future<T> f, String name) async {
  if (ANALYZE_TIME) {
    var start = new DateTime.now();
    var result = await f;
    var diff = new DateTime.now().difference(start);
    print('> $name took ${diff.inMilliseconds}ms');
    return result;
  } else {
    return await f;
  }
}