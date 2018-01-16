import 'dart:async';
import 'dart:io';

import 'package:git_revision/git/git_commands.dart';

class GitVersionerConfig {
  String baseBranch;
  String repoPath;

  GitVersionerConfig(this.baseBranch, this.repoPath)
      : assert(baseBranch != null);
}

class GitVersioner {
  final GitCommands gitCommands;
  final GitVersionerConfig config;

  GitVersioner(this.gitCommands, this.config);

  Future<int> _revision;

  Future<int> get revision async => _revision ??= () async {
        var start = new DateTime.now();
        // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
        //
        // Author date: when a commit was originally authored. Typically, when someone first ran git commit.
        // Commit date: when a commit was applied to the branch. In many cases it is the same as the author date. Sometimes it differs: if a commit was amended, rebased, or applied by someone other than the author as part of a patch. In those cases, the date will be when the rebase happened or the patch was applied.
        // via https://docs.microsoft.com/en-us/vsts/git/concepts/git-dates
        var result = await Process.run(
            'git', ['rev-list', '--pretty=%cI%n', config.baseBranch],
            workingDirectory: config?.repoPath);
        var stdout = result.stdout as String;
        var commits =
            stdout.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
          var lines = rawCommit.split('\n');
          return new Commit(
              lines[0].replaceFirst('commit ', ''), DateTime.parse(lines[1]));
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

  Future<Revision> get branchName async => gitCommands.currentBranch;

  Future<Sha1> get sha1 async => gitCommands.currentSha1;
}

class Commit {
  String sha1;
  DateTime date;

  Commit(this.sha1, this.date);

  @override
  String toString() {
    return 'Commit{sha1: ${sha1.substring(0, 7)}, date: ${date
      .millisecondsSinceEpoch}';
  }
}
