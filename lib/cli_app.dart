import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:git_revision/git_revision.dart';

part 'cli_app.g.dart';

class CliApp {
  final CliLogger logger;

  // manual injection of the [GitVersioner]
  final GitVersioner? Function(GitVersionerConfig config) versionerProvider;

  CliApp(this.logger, this.versionerProvider);

  CliApp.production([CliLogger logger = const CliLogger()])
      : this(logger, (config) => GitVersioner(config));

  Future<void> process(List<String> args) async {
    final cliArgs = parseCliArgs(args);

    if (cliArgs.showHelp) {
      showUsage();
      return;
    }

    if (cliArgs.showVersion) {
      showVersion();
      return;
    }

    final versioner = versionerProvider(cliArgs.toConfig())!;

    if (cliArgs.fullOutput) {
      logger.stdOut(
        trimLines(
          '''
        versionCode: ${await versioner.revision}
        versionName: ${await versioner.versionName}
        baseBranch: ${await versioner.baseBranch}
        currentBranch: ${await versioner.headBranchName}
        sha1: ${await versioner.sha1}
        sha1Short: ${(await versioner.sha1)?.substring(0, 7)}
        completeFirstOnlyBaseBranchCommitCount: ${(await versioner.allFirstBaseBranchCommits).length}
        baseBranchCommitCount: ${(await versioner.baseBranchCommits).length}
        baseBranchTimeComponent: ${await versioner.baseBranchTimeComponent}
        featureBranchCommitCount: ${(await versioner.featureBranchCommits).length}
        featureBranchTimeComponent: ${await versioner.featureBranchTimeComponent}
        featureOrigin: ${(await versioner.featureBranchOrigin)?.sha1}
        yearFactor: ${versioner.config.yearFactor}
        localChanges: ${await versioner.localChanges}
        ''',
        ),
      );
    } else {
      // default output
      final revision = await versioner.versionName;
      logger.stdOut(revision);
    }
  }

  static final _cliArgParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('version',
        abbr: 'v',
        help: 'Shows the version information of git revision',
        negatable: false)
    ..addOption(
      'context',
      abbr: 'C',
      help:
          '<path> Run as if git was started in <path> instead of the current working directory',
    )
    ..addOption(
      'baseBranch',
      abbr: 'b',
      help:
          'The base branch where most of the development happens, (defaults to master, or main). Often what is set as baseBranch in github. Only on the baseBranch the revision can become only digits.',
    )
    ..addOption(
      'yearFactor',
      abbr: 'y',
      help: 'revision increment count per year',
      defaultsTo: GitVersioner.defaultYearFactor.toString(),
    )
    ..addOption(
      'stopDebounce',
      abbr: 'd',
      defaultsTo: GitVersioner.defaultStopDebounce.toString(),
      help: 'time between two commits '
          'which are further apart than this stopDebounce (in hours) will not be included into the timeComponent. '
          'A project on hold for a few months will therefore not increase the revision drastically when development '
          'starts again.',
    )
    ..addOption(
      'name',
      abbr: 'n',
      help:
          "a human readable name and identifier of a revision ('73_<name>+21_996321c'). "
          "Can be anything which gives the revision more meaning i.e. the number of the PullRequest when building on CI. "
          "Allowed characters: [a-zA-Z0-9_-/] any letter, digits, underscore, dash and slash. Invalid characters will be removed.",
    )
    ..addFlag(
      'full',
      help:
          'shows full information about the current revision and extracted information',
      negatable: false,
    );

  static GitRevisionCliArgs parseCliArgs(List<String> args) {
    final ArgResults argResults = _cliArgParser.parse(args);

    final parsedCliArgs = GitRevisionCliArgs();

    parsedCliArgs.showHelp = argResults['help'] as bool;
    parsedCliArgs.showVersion = argResults['version'] as bool;
    parsedCliArgs.fullOutput = argResults['full'] as bool;
    parsedCliArgs.repoPath = argResults['context'] as String?;
    parsedCliArgs.baseBranch = argResults['baseBranch'] as String?;
    parsedCliArgs.yearFactor = intArg(argResults, 'yearFactor');
    parsedCliArgs.stopDebounce = intArg(argResults, 'stopDebounce');
    if (argResults.rest.length == 1) {
      final rest = argResults.rest[0];
      if (rest.isNotEmpty) {
        parsedCliArgs.revision = rest;
      }
    } else if (argResults.rest.length > 1) {
      throw ArgError(
          'expected only one revision argument, found ${argResults.rest.length}: ${argResults.rest}');
    }

    final String? rawName = argResults['name'] as String?;
    if (rawName != null) {
      String safeName =
          rawName.replaceAll(RegExp(r'[^\w_\-\/]+'), '_').replaceAll('__', '_');

      // trim underscore at start and end
      if (safeName[0] == '_') {
        safeName = safeName.substring(1, safeName.length - 1);
      }
      if (safeName[safeName.length - 1] == '_') {
        safeName = safeName.substring(0, safeName.length - 2);
      }

      if (safeName.isNotEmpty && safeName != '_') {
        parsedCliArgs.name = safeName;
      }
    }

    return parsedCliArgs;
  }

  static int intArg(ArgResults args, String name) {
    final raw = (args[name] as String?)?.trim();
    try {
      return int.parse(raw!);
    } on FormatException {
      throw ArgError("$name is not a integer '$raw'");
    }
  }

  void showUsage() {
    logger.stdOut(
        "git revision creates a useful revision for your project beyond 'git describe'");
    logger.stdOut(_cliArgParser.usage);
  }

  void showVersion() {
    logger.stdOut("Version $versionName");
  }
}

String trimLines(String text) =>
    text.split('\n').map((line) => line.trimLeft()).join('\n').trim();

class GitRevisionCliArgs {
  bool showHelp = false;
  bool showVersion = false;

  String? repoPath;
  String revision = 'HEAD';
  String? name;
  String? baseBranch;
  int yearFactor = GitVersioner.defaultYearFactor;
  int stopDebounce = GitVersioner.defaultStopDebounce;

  bool fullOutput = false;

  @override
  String toString() =>
      'GitRevisionCliArgs{helpFlag: $showHelp, versionFlag: $showVersion, baseBranch: $baseBranch, repoPath: $repoPath, yearFactor: $yearFactor, stopDebounce: $stopDebounce}';

  GitVersionerConfig toConfig() => GitVersionerConfig(
      baseBranch, repoPath, yearFactor, stopDebounce, name, revision);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRevisionCliArgs &&
          runtimeType == other.runtimeType &&
          showHelp == other.showHelp &&
          showVersion == other.showVersion &&
          repoPath == other.repoPath &&
          revision == other.revision &&
          name == other.name &&
          baseBranch == other.baseBranch &&
          yearFactor == other.yearFactor &&
          stopDebounce == other.stopDebounce &&
          fullOutput == other.fullOutput;

  @override
  int get hashCode =>
      showHelp.hashCode ^
      showVersion.hashCode ^
      repoPath.hashCode ^
      revision.hashCode ^
      name.hashCode ^
      baseBranch.hashCode ^
      yearFactor.hashCode ^
      stopDebounce.hashCode ^
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
