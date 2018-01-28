import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:git_revision/git_revision.dart';

typedef GitVersioner GitVersionerProvider(GitVersionerConfig config);

class CliApp {
  final CliLogger logger;

  // manual injection of the [GitVersioner]
  final GitVersionerProvider versionerProvider;

  CliApp(this.logger, this.versionerProvider)
      : assert(logger != null),
        assert(versionerProvider != null);

  CliApp.production([CliLogger logger = const CliLogger()]) : this(logger, (config) => new GitVersioner(config));

  Future<Null> process(List<String> args) async {
    final cliArgs = parseCliArgs(args);
    assert(cliArgs != null);

    if (cliArgs.showHelp) {
      showUsage();
      return;
    }

    if (cliArgs.showVersion) {
      showVersion();
      return;
    }

    var versioner = versionerProvider(cliArgs.toConfig());
    assert(versioner != null);

    if (cliArgs.fullOutput) {
      logger.stdOut(trimLines('''
        versionCode: ${await versioner.revision}
        versionName: ${await versioner.versionName}
        baseBranch: ${versioner.config.baseBranch}
        currentBranch: ${await versioner.branchName}
        sha1: ${await versioner.sha1}
        sha1Short: ${(await versioner.sha1).substring(0, 7)}
        baseBranchCommitCount first-only: ${(await versioner.firstBaseBranchCommits).length}
        baseBranchCommitCount: ${(await versioner.baseBranchCommits).length}
        baseBranchTimeComponent: ${await versioner.baseBranchTimeComponent}
        featureBranchCommitCount: ${(await versioner.featureBranchCommits).length}
        featureBranchTimeComponent: ${(await versioner.featureBranchTimeComponent)}
        featureOrigin: ${(await versioner.featureBranchOrigin).sha1}
        yearFactor: ${versioner.config.yearFactor}
        '''));
    } else {
      // default output
      var revision = await versioner.versionName;
      logger.stdOut(revision);
    }
  }

  static final _cliArgParser = new ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('version', abbr: 'v', help: 'Shows the version information of git revision', negatable: false)
    ..addOption('context',
        abbr: 'C', help: '<path> Run as if git was started in <path> instead of the current working directory')
    ..addOption('baseBranch',
        abbr: 'b',
        help:
            'The base branch where most of the development happens. Often what is set as baseBranch in github. Only on the baseBranch the revision can become only digits.',
        defaultsTo: GitVersioner.DEFAULT_BRANCH.toString())
    ..addOption('yearFactor',
        abbr: 'y', help: 'revision increment count per year', defaultsTo: GitVersioner.DEFAULT_YEAR_FACTOR.toString())
    ..addOption(
      'stopDebounce',
      abbr: 'd',
      defaultsTo: GitVersioner.DEFAULT_STOP_DEBOUNCE.toString(),
      help: 'time between two commits '
          'which are further apart than this stopDebounce (in hours) will not be included into the timeComponent. '
          'A project on hold for a few months will therefore not increase the revision drastically when development '
          'starts again.',
    )
    ..addFlag('full',
        help: 'shows full information about the current revision and extracted information', negatable: false);

  static GitRevisionCliArgs parseCliArgs(List<String> args) {
    ArgResults argResults = _cliArgParser.parse(args);

    var parsedCliArgs = new GitRevisionCliArgs();

    parsedCliArgs.showHelp = argResults['help'];
    parsedCliArgs.showVersion = argResults['version'];
    parsedCliArgs.fullOutput = argResults['full'];
    parsedCliArgs.repoPath = argResults['context'];
    parsedCliArgs.baseBranch = argResults['baseBranch'];
    parsedCliArgs.yearFactor = intArg(argResults, 'yearFactor');
    parsedCliArgs.stopDebounce = intArg(argResults, 'stopDebounce');
    if (argResults.rest.length == 1) {
      var rest = argResults.rest[0];
      if (rest.isNotEmpty) {
        parsedCliArgs.revision = rest;
      }
    } else if (argResults.rest.length > 1) {
      throw new ArgError('expected only one revision argument, found ${argResults.rest.length}: ${argResults.rest}');
    }

    return parsedCliArgs;
  }

  static int intArg(ArgResults args, String name) {
    var raw = (args[name] as String)?.trim();
    try {
      return int.parse(raw);
    } on FormatException {
      throw new ArgError("$name is not a integer '$raw'");
    }
  }

  void showUsage() {
    logger.stdOut("git revision creates a useful revision for your project beyond 'git describe'");
    logger.stdOut(_cliArgParser.usage);
  }

  void showVersion() {
    logger.stdOut("Version 0.4.0");
  }
}

String trimLines(String text) => text.split('\n').map((line) => line.trimLeft()).join('\n').trim();

class GitRevisionCliArgs {
  bool showHelp = false;
  bool showVersion = false;

  String repoPath;
  String revision = 'HEAD';
  String baseBranch = GitVersioner.DEFAULT_BRANCH;
  int yearFactor = GitVersioner.DEFAULT_YEAR_FACTOR;
  int stopDebounce = GitVersioner.DEFAULT_STOP_DEBOUNCE;

  bool fullOutput = false;

  @override
  String toString() =>
      'GitRevisionCliArgs{helpFlag: $showHelp, versionFlag: $showVersion, baseBranch: $baseBranch, repoPath: $repoPath, yearFactor: $yearFactor, stopDebounce: $stopDebounce}';

  GitVersionerConfig toConfig() => new GitVersionerConfig(baseBranch, repoPath, yearFactor, stopDebounce, revision);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRevisionCliArgs &&
          runtimeType == other.runtimeType &&
          showHelp == other.showHelp &&
          showVersion == other.showVersion &&
          baseBranch == other.baseBranch &&
          repoPath == other.repoPath &&
          yearFactor == other.yearFactor &&
          stopDebounce == other.stopDebounce &&
          revision == other.revision &&
          fullOutput == other.fullOutput;

  @override
  int get hashCode =>
      showHelp.hashCode ^
      showVersion.hashCode ^
      baseBranch.hashCode ^
      repoPath.hashCode ^
      yearFactor.hashCode ^
      stopDebounce.hashCode ^
      revision.hashCode ^
      fullOutput.hashCode;
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
