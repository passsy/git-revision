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

  GitVersioner(this.config);

  Future<int> _revision;

  Future<int> get revision async => _revision ??= () async {
        var commits = await baseBranchCommits();
        var timeComponent = _timeComponent(commits);
        return commits.length + timeComponent;
      }();

  Future<String> get versionName => revision.then((count) {
        //TODO use formatter
        return "$count";
      });

  Future<String> _currentBranch;

  Future<String> get branchName async => _currentBranch ??= () async {
        await _verifyGitWorking();
        var name = stdoutText(await Process.run('git', ['symbolic-ref', '--short', '-q', 'HEAD'])).trim();

        assert(() {
          if (name.split('\n').length != 1) throw new ArgumentError("branch name is multiline '$name'");
          return true;
        }());
        // empty branch names can't exits this means no branch name
        if (name.isEmpty) return null;
        return name;
      }();

  Future<String> _sha1;

  Future<String> get sha1 async => _sha1 ??= () async {
        await _verifyGitWorking();
        var hash = stdoutText(await Process.run('git', ['rev-parse', 'HEAD'])).trim();

        assert(() {
          if (hash.isEmpty) throw new ArgumentError("sha1 is empty ''");
          if (hash.split('\n').length != 1) throw new ArgumentError("sha1 is multiline '$hash'");
          return true;
        }());

        return hash;
      }();

  Future<List<Commit>> _commitsToHeadCache;

  Future<List<Commit>> commitsToHead() {
    return _commitsToHeadCache ??= _commitsUpTo('HEAD');
  }

  Future<List<Commit>> _baseBranchCommits;

  Future<List<Commit>> baseBranchCommits() {
    return _baseBranchCommits ??= _commitsUpTo(config.baseBranch);
  }

  Future<List<Commit>> _featureBranchCommits;

  Future<List<Commit>> featureBranchCommits() {
    return _featureBranchCommits ??= () async {
      var base = await baseBranchCommits();
      var feature = await commitsToHead();

      return feature.where((c) => !base.contains(c)).toList(growable: false);
    }();
  }

  Future<List<Commit>> _commitsUpTo(String to) async {
    // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
    //
    // Author date: when a commit was originally authored. Typically, when someone first ran git commit.
    // Commit date: when a commit was applied to the branch. In many cases it is the same as the author date. Sometimes it differs: if a commit was amended, rebased, or applied by someone other than the author as part of a patch. In those cases, the date will be when the rebase happened or the patch was applied.
    // via https://docs.microsoft.com/en-us/vsts/git/concepts/git-dates
    var result = await Process.run('git', ['rev-list', '--pretty=%cI%n', to], workingDirectory: config?.repoPath);
    var stdout = result.stdout as String;
    var commits = stdout.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
      var lines = rawCommit.split('\n');
      return new Commit(lines[0].replaceFirst('commit ', ''), DateTime.parse(lines[1]));
    }).toList(growable: false);

    return commits;
  }

  /// `null` when ready, errors otherwise
  Future<Null> _verifyGitWorking() async => null;

  Future<int> baseBranchTimeComponent() => baseBranchCommits().then((commits) => _timeComponent(commits));

  Future<int> featureBranchTimeComponent() => featureBranchCommits().then((commits) => _timeComponent(commits));

  int _timeComponent(List<Commit> commits) {
    assert(commits != null);
    if (commits.isEmpty) return 0;

    var completeTime = commits.last.date.difference(commits.first.date).abs();
    if (completeTime == Duration.zero) return 0;

    print("time ${completeTime.inDays}d");
    var completeTimeComponent = _yearFactor(completeTime);
    print("naive time component $completeTimeComponent");

    // find gaps
    var gaps = Duration.zero;
    for (var i = 1; i < commits.length; i++) {
      var prev = commits[i];
      // rev-list comes in reversed order
      var next = commits[i - 1];
      var diff = next.date.difference(prev.date).abs();
      if (diff.inHours >= config.stopDebounce) {
        print("${diff.inDays.abs()}d gap at ${prev.date
            .toUtc()
            .day}/${prev.date
            .toUtc()
            .month}/${prev.date
            .toUtc()
            .year} between ${next.sha1.substring(0, 7)} and ${prev.sha1.substring(0, 7)}");
        gaps += diff;
      }
    }

    print("combined gap ${gaps.inDays}d");

    var gapTimeComponent = _yearFactor(gaps);
    print('gap timeComponent $gapTimeComponent');

    var timeComponent = completeTimeComponent - gapTimeComponent;
    print("time component without gaps: $timeComponent");

    return timeComponent;
  }

  int _yearFactor(Duration duration) => (duration.inSeconds * config.yearFactor / _YEAR.inSeconds + 0.5).toInt();
}
