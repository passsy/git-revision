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

      expect(out, contains('versionCode: 1'));
      expect(out, contains('baseBranch: master'));
      expect(out, contains('currentBranch: master'));
      expect(out, contains('baseBranchCommitCount: 1'));
      expect(out, contains('featureBranchCommitCount: 0'));
      expect(out, contains('baseBranchTimeComponent: 0'));
      expect(out, contains('featureBranchCommitCount: 0'));
      expect(out, contains('featureBranchTimeComponent: 0'));
      expect(out, contains('yearFactor: 1000'));
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

      expect(out, contains('versionCode: 6'));
      expect(out, contains('baseBranch: master'));
      expect(out, contains('currentBranch: master'));
      expect(out, contains('baseBranchCommitCount: 3'));
      expect(out, contains('baseBranchTimeComponent: 3'));
      expect(out, contains('featureBranchCommitCount: 0'));
      expect(out, contains('featureBranchTimeComponent: 0'));
      expect(out, contains('yearFactor: 1000'));
    });

    test("merge branch with old commits doesn't increase the revision of previous commits", () async {
      git.skipCleanup = true;
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
      expect(out2, contains('versionCode: 8'));

      await git.run(name: 'go back to commit before merge', script: sh("""
          git checkout master
          git checkout HEAD^1
          """));

      // same revision as before
      var out3 = await git.revision(['revision']);
      expect(out3, contains('versionCode: 3'));
    });
  });

  group('feature branch', () {
    TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test("merge branch with old commits doesn't increase the revision of previous commits", () async {
      git.skipCleanup = true;
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
      expect(out2, contains('versionCode: 8'));

      await git.run(name: 'go back on master to commit before merge', script: sh("""
          git checkout master
          git checkout HEAD^1
          """));

      // same revision as before
      var out3 = await git.revision(['revision']);
      expect(out3, contains('versionCode: 3'));
    });
  });
}

class TempGit {
  /// set to `true` for debugging to skip deletion of the repo folder
  bool skipCleanup = false;

  TempGit();

  io.Directory repo;
  io.Directory root;

  String get path => root.path;

  final String _slash = io.Platform.pathSeparator;
  int _scriptCount = 0;

  Future<Null> setup() async {
    root = await io.Directory.systemTemp.createTemp('git-revision-integration-test');
    var path = "${root.path }${_slash}repo";
    repo = await new io.Directory(path).create();
  }

  Future<Null> cleanup() async {
    if (skipCleanup) return;
    await root.delete(recursive: true);
  }

  Future<Null> run({String name, @required String script}) async {
    assert(script != null);
    assert(script.isNotEmpty);
    var namePostfix = name != null ? "_$name".replaceAll(" ", "_") : "";
    var scriptName = "script${_scriptCount++}$namePostfix.sh";
    var path = "${root.path}$_slash$scriptName";
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

    printOnFailure("\nrunning '$scriptName':");
    printOnFailure("\n$scriptText\n\n");
    var scriptResult = await io.Process.run('../$scriptName', [], workingDirectory: repo.path, runInShell: true);
    _throwOnError(scriptResult);
  }

  Future<String> revision(List<String> args) async {
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
