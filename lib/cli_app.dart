import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli/commander.dart';
import 'package:git_revision/git_revision.dart';

class RevisionCommand extends Command {
  final String name = 'revision';
  final String description = '//TODO';

  final CliApp app;

  RevisionCommand(this.app) {
    argParser.addOption('baseBranch', abbr: 'b', help: 'baseBranch');
  }

  @override
  Future run() async {
    String where = globalResults['context']?.trim();
    String baseBranch = argResults['baseBranch'] ?? 'master';

    var gitVersioner = app.versionerProvider(new GitVersionerConfig(baseBranch, where));

    //var count = await test(where?.trim(), baseBranch);
    //logger.stdOut("commit count: $count");

    var revision = await gitVersioner.revision;
    var name = await gitVersioner.versionName;

    logger.stdOut('''
Revision: $revision
Version name: $name
commit count: $revision
sha1: ${await gitVersioner.sha1}
branch: ${await gitVersioner.branchName}
      ''');

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

typedef GitVersioner VersionerProvider(GitVersionerConfig config);

class CliApp {
  Commander runner;
  final CliLogger logger;
  VersionerProvider versionerProvider = (config) {
    return new GitVersioner(config);
  };

  CliApp(this.logger) : assert(logger != null) {
    runner = new Commander('git revision', 'Welcome to git revision!')
      ..logger = logger
      ..addCommand(new VersionCommand())
      ..addCommand(new RevisionCommand(this));
  }

  CliApp.production([CliLogger logger = const CliLogger()]) : this(logger);

  Future process(List<String> args) => runner.run(args);
}

// TODO move out of implementation
class CliLogger {
  const CliLogger();

  void stdOut(String s) => io.stdout.writeln(s);

  void stdErr(String s) => io.stderr.writeln(s);
}

class ArgError implements Exception {
  final String message;

  ArgError(this.message);

  @override
  String toString() => message;
}
