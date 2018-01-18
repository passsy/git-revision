import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli_app.dart';
import 'package:test/test.dart';

import 'cli_app_test.dart';

void main() {
  group('master only', () {
    var time = new DateTime(2017, DateTime.JANUARY, 10);
    TempDir tempDir;
    setUp(() async {
      tempDir = new TempDir();
      await tempDir.setup();
      printOnFailure("cd ${tempDir.repo.path} && git log --pretty=fuller");
    });

    tearDown(() async {
      await tempDir.cleanup();
    });

    Future<String> runGitRevision(List<String> args) async {
      var logger = new MockLogger();
      var cliApp = new CliApp.production(logger);
      await cliApp.process(['-C ${tempDir.repo.path}']..addAll(args));
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

    test('first commmit', () async {
      await tempDir.run(name: 'init commit', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", time)}
          """));

      var out = await runGitRevision(['revision']);

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
      await tempDir.run(name: 'init with 3 commits', script: sh("""
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", time)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", time.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", time.add(day))}
          """));

      var out = await runGitRevision(['revision']);

      expect(out, contains('versionCode: 6'));
      expect(out, contains('baseBranch: master'));
      expect(out, contains('currentBranch: master'));
      expect(out, contains('baseBranchCommitCount: 3'));
      expect(out, contains('baseBranchTimeComponent: 3'));
      expect(out, contains('featureBranchCommitCount: 0'));
      expect(out, contains('featureBranchTimeComponent: 0'));
      expect(out, contains('yearFactor: 1000'));
    });
  });
}

class TempDir {
  TempDir();

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

  Future<Null> cleanup() => root.delete(recursive: true);

  Future<Null> run({String name, String script}) async {
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
    throwOnError(permission);

    printOnFailure("\nrunning '$scriptName':");
    printOnFailure("\n$scriptText\n\n");
    var scriptResult = await io.Process.run('../$scriptName', [], workingDirectory: repo.path, runInShell: true);
    throwOnError(scriptResult);
  }
}

var hour = const Duration(hours: 1);
var day = const Duration(days: 1);
var minutes = const Duration(minutes: 1);

String commit(String message, DateTime date, [bool add = true]) => sh("""
    export GIT_COMMITTER_DATE="${date.toIso8601String()}"
    git commit -${add ? 'a' : ''}m "$message" --date "\$GIT_COMMITTER_DATE"
    unset GIT_COMMITTER_DATE
    """);

String write(String filename, String text) => sh("""echo "$text" > $filename""");

/// trims the script
String sh(String script) => script.split('\n').map((line) => line.trimLeft()).join('\n').trim();

void throwOnError(io.ProcessResult processResult) {
  printOnFailure(processResult.stdout);
  if (processResult.exitCode != 0) {
    io.stderr.write("Exit code: ${processResult.exitCode}");
    io.stderr.write(processResult.stderr);
    throw new io.ProcessException("", [], processResult.stderr, processResult.exitCode);
  }
}
