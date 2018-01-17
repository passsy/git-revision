import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:git_revision/cli/commander.dart';
import 'package:git_revision/git_revision.dart';

class RevisionCommand extends Command {
  final String name = 'revision';
  final String description = '//TODO';

  final CliApp app;

  RevisionCommand(this.app) {
    argParser.addOption('baseBranch', abbr: 'b', help: 'baseBranch', defaultsTo: 'master');
    argParser.addOption('yearFactor', abbr: 'y', help: 'increment count per year', defaultsTo: '1000');
    argParser.addOption('stopDebounce',
        abbr: 'd',
        help:
            'time between two commits which are further apart than this stopDebounce (in hours) will not be included into the timeComponent. A project on hold for a few months will therefore not increase the revision drastically when development starts again.',
        defaultsTo: '48');
  }

  @override
  Future run() async {
    String where = globalResults['context']?.trim();
    String baseBranch = argResults['baseBranch'];
    assert(baseBranch != null);

    int yearFactor = intArg(argResults, 'yearFactor');
    int stopDebounce = intArg(argResults, 'stopDebounce');
    var gitVersioner = app.versionerProvider(new GitVersionerConfig(baseBranch, where, yearFactor, stopDebounce));

    var revision = await gitVersioner.revision;
    var versionName = await gitVersioner.versionName;

    logger.stdOut('''
        versionCode: $revision
        versionName: $versionName
        baseBranch: ${gitVersioner.config.baseBranch}
        currentBranch: ${await gitVersioner.branchName}
        sha1: ${await gitVersioner.sha1}
        sha1Short: ${(await gitVersioner.sha1).substring(0, 7)}
        baseBranchCommitCount: ${(await gitVersioner.baseBranchCommits).length}
        baseBranchTimeComponent: ${await gitVersioner.baseBranchTimeComponent}
        featureBranchCommitCount: ${(await gitVersioner.featureBranchCommits).length}
        featureBranchTimeComponent: ${(await gitVersioner.featureBranchTimeComponent)}
        yearFactor: ${gitVersioner.config.yearFactor}
        '''
        .split('\n')
        .map((l) => l.trimLeft())
        .join('\n'));

    return null;
  }
}

int intArg(ArgResults args, String name) {
  var raw = args[name] as String;
  try {
    return int.parse(raw);
  } on FormatException {
    throw new ArgError("name is not a integer '$raw'");
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
