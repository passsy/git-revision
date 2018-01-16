import 'dart:async';
import 'dart:io';

import 'package:git_revision/git/git_commands.dart';
import 'package:git_revision/util/process_utils.dart';

class GitVersionerConfig {
  String baseBranch;
  String repoPath;

  GitVersionerConfig(this.baseBranch, this.repoPath) : assert(baseBranch != null);
}

class GitVersioner {
  final GitVersionerConfig config;

  GitVersioner(this.config);

  Future<int> _revision;

  Future<int> get revision async => _revision ??= () async {
        var start = new DateTime.now();
        // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
        //
        // Author date: when a commit was originally authored. Typically, when someone first ran git commit.
        // Commit date: when a commit was applied to the branch. In many cases it is the same as the author date. Sometimes it differs: if a commit was amended, rebased, or applied by someone other than the author as part of a patch. In those cases, the date will be when the rebase happened or the patch was applied.
        // via https://docs.microsoft.com/en-us/vsts/git/concepts/git-dates
        var result = await Process.run('git', ['rev-list', '--pretty=%cI%n', config.baseBranch],
            workingDirectory: config?.repoPath);
        var stdout = result.stdout as String;
        var commits = stdout.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
          var lines = rawCommit.split('\n');
          return new Commit(lines[0].replaceFirst('commit ', ''), DateTime.parse(lines[1]));
        }).toList();

        for (var i = 1; i < commits.length; i++) {
          var prev = commits[i];
          // rev-list comes in reversed order
          var next = commits[i - 1];
          var diff = next.date.difference(prev.date);
          if (diff.inDays.abs() >= 2) {
            print("large gap (${diff.inDays.abs()}d) at ${prev.date
                .toUtc()
                .weekday} between ${next.sha1} and ${prev.sha1}");
          }
        }

        var diff = new DateTime.now().difference(start);
        print("revision calculation time: ${diff.inMilliseconds}ms");

        return commits.length;
      }();

  Future<String> get versionName => revision.then((count) => "$count");

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

  /// `null` when ready, errors otherwise
  Future<Null> _verifyGitWorking() async => null;
}
