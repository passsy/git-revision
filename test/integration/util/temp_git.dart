import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli_app.dart';
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

  late io.Directory repo;
  late io.Directory root;

  String get path => root.path;

  int _scriptCount = 0;

  Future<void> setup() async {
    root = await io.Directory.systemTemp.createTemp('git-revision-integration-test');
    final path = "${root.path}${io.Platform.pathSeparator}repo";
    repo = await io.Directory(path).create();
  }

  Future<void> cleanup() async {
    if (skipCleanup) return;
    await root.delete(recursive: true);
  }

  Future<void> run({String? name, required String script, io.Directory? repo}) async {
    assert(script.isNotEmpty);
    final namePostfix = name != null ? "_$name".replaceAll(" ", "_") : "";
    final scriptName = "script${_scriptCount++}$namePostfix.sh";
    final path = "${root.path}${io.Platform.pathSeparator}$scriptName";
    final scriptFile = await io.File(path).create();
    final scriptText = sh(
      """
        # Script ${_scriptCount - 1} '$name'
        # Created at ${DateTime.now().toIso8601String()}
        $script
        """,
    );
    await scriptFile.writeAsString(scriptText);

    // execute script
    final permission = await io.Process.run('chmod', ['+x', scriptName], workingDirectory: root.path);
    _throwOnError(permission);

    repo ??= this.repo;
    printOnFailure("\nrunning '$scriptName' in ${repo.path}:");
    printOnFailure("\n$scriptText\n\n");
    final scriptResult = await io.Process.run('../$scriptName', [], workingDirectory: repo.path, runInShell: true);
    _throwOnError(scriptResult);
  }

  Future<String> revision(List<String> args, [io.Directory? repo]) async {
    repo ??= this.repo;
    final logger = MemoryLogger();
    final cliApp = CliApp.production(logger);
    await cliApp.process(['-C', (repo.path), ...args]);
    if (logger.errors.isNotEmpty) {
      print("Error!");
      print(logger.errors);
      throw Exception("CliApp crashed");
    }
    final messages = logger.messages.join('\n');
    printOnFailure("\n> git revision ${args.join(" ")}");
    printOnFailure(messages);
    return messages;
  }
}

Future<TempGit> makeTempGit() async {
  final tempGit = TempGit();
  await tempGit.setup();
  printOnFailure("cd ${tempGit.repo.path} && git log --pretty=fuller");
  addTearDown(() {
    tempGit.cleanup();
  });
  return tempGit;
}

const Duration hour = Duration(hours: 1);
const Duration day = Duration(days: 1);
const Duration minutes = Duration(minutes: 1);

String commit(String message, DateTime date, {bool add = true}) => sh(
      """
    export GIT_COMMITTER_DATE="${date.toIso8601String()}"
    git commit -${add ? 'a' : ''}m "$message" --date "\$GIT_COMMITTER_DATE"
    unset GIT_COMMITTER_DATE
    """,
    );

String merge(String branchToMerge, DateTime date, {bool ff = false}) => sh(
      """
    git merge${ff ? '' : ' --no-ff'} $branchToMerge --no-commit
    ${commit("Merge branch '$branchToMerge'", date)}
""",
    );

void _throwOnError(io.ProcessResult processResult) {
  printOnFailure(processResult.stdout as String);
  if (processResult.exitCode != 0) {
    io.stderr.write("Exit code: ${processResult.exitCode}");
    io.stderr.write(processResult.stderr);
    throw io.ProcessException(
        "",
        [],
        "out:\n"
            "${processResult.stdout as String}\n"
            "err:\n"
            "${processResult.stderr as String}",
        processResult.exitCode);
  }
}

/// trims the script
String sh(String script) => script.split('\n').map((line) => line.trimLeft()).join('\n').trim();
