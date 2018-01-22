import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli_app.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'cli_app_test.dart';

final DateTime initTime = new DateTime(2017, DateTime.JANUARY, 10);

void main() {
  group('master only', () {
    TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test('first commmit', () async {
      await git.run(name: 'init commit', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          """));

      var out = await git.revision(['revision']);

      expect(out, contains('versionCode: 1\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: master\n'));
      expect(out, contains('baseBranchCommitCount first-only: 1\n'));
      expect(out, contains('baseBranchCommitCount: 1\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000\n'));
    });

    test('3 commits', () async {
      await git.run(name: 'init with 3 commits', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day))}
          """));

      var out = await git.revision(['revision']);

      expect(out, contains('versionCode: 6\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: master\n'));
      expect(out, contains('baseBranchCommitCount first-only: 3\n'));
      expect(out, contains('baseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchTimeComponent: 3\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000\n'));
    });

    test("merge branch with old commits doesn't increase the revision of previous commits", () async {
      await git.run(name: 'init master branch', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          """));

      // get current revision, should not change afterwards
      var out1 = await git.revision(['revision']);
      expect(out1, contains('versionCode: 3'));

      await git.run(name: 'merge feature B', script: sh("""
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          git checkout featureB
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          
          git checkout master
          git merge --no-ff featureB
          """));

      // revision obviously increased after merge
      var out2 = await git.revision(['revision']);
      expect(out2, contains('versionCode: 7\n'));

      await git.run(name: 'go back to commit before merge', script: sh("""
          git checkout master
          git checkout HEAD^1
          """));

      // same revision as before
      var out3 = await git.revision(['revision']);
      expect(out3, contains('versionCode: 3\n'));
    });
  });

  group('feature branch', () {
    TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test("feature branch still has +commits after merge in master", () async {
      await git.run(name: 'init master branch - work on featureB', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          
          # Work on featureB
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """));

      var out = await git.revision(['revision']);
      expect(out, contains('versionName: 3_featureB+2\n'));

      await git.run(name: 'continue work on master and merge featureB', script: sh("""
          git checkout master
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day + (hour * 2)))}
          
          # Merge feature branch
          git merge --no-ff featureB
          
          # Go back to feature branch
          git checkout featureB
      """));

      // back on featureB the previous output should not change
      var out2 = await git.revision(['revision']);
      expect(out2, contains('versionName: 3_featureB+2\n'));
    });

    test("git flow - baseBranch=develop - merge develop -> master increases revision", () async {
      await git.run(name: 'init master branch - create develop', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          # Create develop branch
          git checkout -b 'develop'
          """));

      await git.run(name: 'work on feature B', script: sh("""
          git checkout develop
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """));

      await git.run(name: 'work on feature C', script: sh("""
          git checkout develop
          git checkout -b 'featureC'
          echo 'implement feature C' > c.txt
          git add c.txt
          ${commit("implement feature C", initTime.add(day + (hour * 4)))}
          
          echo 'fix a bug' > c.txt
          ${commit("fix bug", initTime.add(day * 2))}
          """));

      await git.run(name: 'work on feature D', script: sh("""
          git checkout develop
          git checkout -b 'featureD'
          echo 'implement feature D' > d.txt
          git add d.txt
          ${commit("implement feature C", initTime.add(day + (hour * 3)))}
          
          echo 'fix more bugs' > d.txt
          ${commit("fix bug", initTime.add(day + (hour * 5)))}
          """));

      await git.run(name: 'merge C then B into develop and release to master', script: sh("""
          git checkout develop
          git merge --no-ff featureC
          git merge --no-ff featureB
          
          git checkout master
          git merge --no-ff develop  
          """));

      await git.run(name: 'merge D into develop and release to mastser', script: sh("""
          git checkout develop
          git merge --no-ff featureD
          
          git checkout master
          git merge --no-ff develop  
          """));

      // master should be only +2 ahead which are the two merge commits (develop -> master)
      // master will always +1 ahead of develop even when merging (master -> develop)
      var out2 = await git.revision(['revision', '--baseBranch', 'develop']);
      expect(out2, contains('versionName: 16_master+2\n'));
    });
  });

  group('remote', () {
    TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test("master only on remote", () async {
      var repo2 = await new io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(name: 'init master branch', repo: repo2, script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """));

      await git.run(name: 'clone and implement feature B', script: sh("""
          git clone ${repo2.path} .
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """));

      var out = await git.revision(['revision']);
      expect(out, contains('versionName: 2_featureB+2\n'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      var out2 = await git.revision(['revision']);
      expect(out2, contains('versionName: 2_featureB+2\n'));
    });

    test("master only on remote which is not called origin", () async {
      var repo2 = await new io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(name: 'init master branch', repo: repo2, script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """));

      await git.run(name: 'clone and implement feature B', script: sh("""
          git clone -o first ${repo2.path} .
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """));

      var out = await git.revision(['revision']);
      expect(out, contains('versionName: 2_featureB+2\n'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      var out2 = await git.revision(['revision']);
      expect(out2, contains('versionName: 2_featureB+2\n'));
    });

    test("master only on one remote - multiple remotes", () async {
      var repo2 = await new io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(name: 'init master branch', repo: repo2, script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """));

      await git.run(name: 'add remotes and start working', script: sh("""
          git init
          git remote add first ${repo2.path}
          git remote add second ${repo2.path}
          git remote add third ${repo2.path}
          
          git remote add zcorrect ${repo2.path}
          git pull --no-commit zcorrect master
          
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          ${commit("implement feature B", initTime.add(hour * 6))}
          """));

      var out = await git.revision(['revision']);
      expect(out, contains('versionName: 2_featureB+1\n'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      var out2 = await git.revision(['revision']);
      expect(out2, contains('versionName: 2_featureB+1\n'));
    });
  });
}

class TempGit {
  /// set to `true` for debugging to skip deletion of the repo folder
  ///
  /// Usage for debugging
  /// ```
  /// git.skipCleanup = true;
  /// print('cd ${git.repo.path} && stree .');
  /// ```
  bool skipCleanup = false;

  TempGit();

  io.Directory repo;
  io.Directory root;

  String get path => root.path;

  int _scriptCount = 0;

  Future<Null> setup() async {
    root = await io.Directory.systemTemp.createTemp('git-revision-integration-test');
    var path = "${root.path }${io.Platform.pathSeparator}repo";
    repo = await new io.Directory(path).create();
  }

  Future<Null> cleanup() async {
    if (skipCleanup) return;
    await root.delete(recursive: true);
  }

  Future<Null> run({String name, @required String script, io.Directory repo}) async {
    assert(script != null);
    assert(script.isNotEmpty);
    var namePostfix = name != null ? "_$name".replaceAll(" ", "_") : "";
    var scriptName = "script${_scriptCount++}$namePostfix.sh";
    var path = "${root.path}${io.Platform.pathSeparator}$scriptName";
    var scriptFile = await new io.File(path).create();
    var scriptText = sh("""
        # Script ${_scriptCount - 1} '$name'
        # Created at ${new DateTime.now().toIso8601String()}
        $script
        """);
    await scriptFile.writeAsString(scriptText);

    // execute script
    var permission = await io.Process.run('chmod', ['+x', scriptName], workingDirectory: root.path);
    _throwOnError(permission);

    repo ??= this.repo;
    printOnFailure("\nrunning '$scriptName' in ${repo.path}:");
    printOnFailure("\n$scriptText\n\n");
    var scriptResult = await io.Process.run('../$scriptName', [], workingDirectory: repo.path, runInShell: true);
    _throwOnError(scriptResult);
  }

  Future<String> revision(List<String> args, [io.Directory repo]) async {
    repo ??= this.repo;
    var logger = new MockLogger();
    var cliApp = new CliApp.production(logger);
    await cliApp.process(['-C ${repo.path}']..addAll(args));
    if (logger.errors.isNotEmpty) {
      print("Error!");
      print(logger.errors);
      throw new Exception("CliApp crashed");
    }
    var messages = logger.messages.join('\n');
    printOnFailure("\n> git revision ${args.join(" ")}");
    printOnFailure(messages);
    return messages;
  }
}

Future<TempGit> makeTempGit() async {
  var tempGit = new TempGit();
  await tempGit.setup();
  printOnFailure("cd ${tempGit.repo.path} && git log --pretty=fuller");
  addTearDown(() {
    tempGit.cleanup();
  });
  return tempGit;
}

const Duration hour = const Duration(hours: 1);
const Duration day = const Duration(days: 1);
const Duration minutes = const Duration(minutes: 1);

String commit(String message, DateTime date, [bool add = true]) => sh("""
    export GIT_COMMITTER_DATE="${date.toIso8601String()}"
    git commit -${add ? 'a' : ''}m "$message" --date "\$GIT_COMMITTER_DATE"
    unset GIT_COMMITTER_DATE
    """);

/// trims the script
String sh(String script) => script.split('\n').map((line) => line.trimLeft()).join('\n').trim();

void _throwOnError(io.ProcessResult processResult) {
  printOnFailure(processResult.stdout);
  if (processResult.exitCode != 0) {
    io.stderr.write("Exit code: ${processResult.exitCode}");
    io.stderr.write(processResult.stderr);
    throw new io.ProcessException("", [], processResult.stderr, processResult.exitCode);
  }
}
