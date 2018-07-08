import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli_app.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../../unit/util/memory_logger.dart';

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
    var path = "${root.path}${io.Platform.pathSeparator}repo";
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
    var logger = new MemoryLogger();
    var cliApp = new CliApp.production(logger);
    await cliApp.process(['-C', '${repo.path}']..addAll(args));
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

void merge(String branchToMerge, DateTime date, [bool ff = false]) => sh("""
    git merge${ff ? '' : ' --no-ff'} $branchToMerge --no-commit
    ${commit("Merge branch '$branchToMerge'", date)}
""");

void _throwOnError(io.ProcessResult processResult) {
  printOnFailure(processResult.stdout);
  if (processResult.exitCode != 0) {
    io.stderr.write("Exit code: ${processResult.exitCode}");
    io.stderr.write(processResult.stderr);
    throw new io.ProcessException("", [], processResult.stderr, processResult.exitCode);
  }
}

/// trims the script
String sh(String script) => script.split('\n').map((line) => line.trimLeft()).join('\n').trim();
