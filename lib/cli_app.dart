import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli/commander.dart';
import 'package:git_revision/git/shell_git_extractor.dart';
import 'package:git_revision/git_revision.dart';

class InitCommand extends Command {
  final String name = 'init';
  final String description =
      'Creates a configuration file `.gitrevision.yaml` to add a fixed config to this project';

  InitCommand() {
    argParser
      ..addOption('format',
          abbr: 'f',
          help: 'format options',
          defaultsTo: 'revision',
          allowed: ['revision', 'more will come...'])
      ..addOption('baseBranch',
          abbr: 'b',
          defaultsTo: 'master',
          help: 'The branch you work on most of the time');
  }

  @override
  Null run() {
    if (argResults['format'] == null) {
      throw new ArgError('require format arg');
    }
    return null;
  }
}

class RevisionCommand extends Command {
  final String name = 'revision';
  final String description = '//TODO';

  final GitVersioner gitVersioner;

  RevisionCommand(this.gitVersioner);

  @override
  Future run() async {
    if (argResults.arguments.isEmpty) {
      assert(() {
        if (gitVersioner == null)
          throw new ArgumentError.notNull('gitVersioner');
        return true;
      }());

      var revision = await gitVersioner.revision;
      var name = await gitVersioner.versionName;

      logger.stdOut('''
Revision: $revision
Version name: $name
sha1: ${await gitVersioner.sha1}
branch: ${await gitVersioner.branchName}
      ''');
    }

    return null;
  }
}

class VersionCommand extends Command {
  final String name = 'version';
  final String description = 'Shows the version information';

  VersionCommand();

  @override
  void run() {
    //TODO
    logger.stdOut('Version 0.1.0');
  }
}

class CliApp {
  final GitVersioner gitVersioner;
  Commander runner;
  final CliLogger logger;

  CliApp(this.gitVersioner, this.logger) : assert(logger != null) {
    runner = new Commander('git revision', 'Welcome to git revision!')
      ..logger = logger
      //..addCommand(new InitCommand())
      ..addCommand(new VersionCommand())
      ..addCommand(new RevisionCommand(gitVersioner));
  }

  CliApp.production()
      : this(new GitVersioner(new ShellGitExtractor()), new CliLogger());

  Future process(List<String> args) async {
    return await runner.run(args);
  }
}

// TODO move out of implementation
class CliLogger {
  void stdOut(String s) => io.stdout.writeln(s);

  void stdErr(String s) => io.stderr.writeln(s);
}

class ArgError implements Exception {
  final String message;

  ArgError(this.message);

  @override
  String toString() => message;
}
