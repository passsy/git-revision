import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:git_revision/git_revision.dart';

class CliApp {
  final CliLogger logger;
  final GitVersioner gitVersioner;

  CliApp(this.gitVersioner, this.logger) : assert(logger != null);

  CliApp.production()
      : gitVersioner = new GitVersioner(),
        logger = new CliLogger();

  static ArgParser _initParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('format',
        abbr: 'f',
        help: 'format options',
        defaultsTo: 'revision',
        allowed: ['revision', 'more will come...'])
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('baseBranch',
        abbr: 'b',
        defaultsTo: 'master',
        help: 'The branch you work on most of the time');

  static ArgParser _argParser = new ArgParser(allowTrailingOptions: true)
    ..addFlag('version',
        abbr: 'v', negatable: false, help: 'Shows the version information')
    ..addCommand('version')
    ..addFlag('help',
        abbr: 'h',
        negatable: false,
        help:
            "Shows a help message for a given command 'git revision init --help'")
    ..addCommand('help')
    ..addCommand('init', _initParser);

  Future process(List<String> args) async {
    final ArgResults options = _argParser.parse(args);

    if (args.isEmpty) {
      assert(() {
        if (gitVersioner == null)
          throw new ArgumentError.notNull('gitVersioner');
        return true;
      }());

      var revision = await gitVersioner.revision();
      var name = await gitVersioner.versionName();

      logger.stdOut('''
Revision: $revision
Version name: $name
      ''');
      return null;
    }

    if (options['help'] == true || options.command?.name == 'help') {
      logger.stdOut('''
Welcome to git revision! This tool helps to generate useful version numbers and
revision codes for your project. Semantic versioning (i.e. "1.4.2") is nice but 
only useful for end users. Wouldn't it be nice if each commit had a unique 
revision which is meaningful and comparable?

Usage:
      ''');

      logger.stdOut(_argParser.usage);

      logger.stdOut('''

Commands:

init\tCreates a configuration file (.gitrevision.yaml)
help\tShows this help text
      ''');
      return null;
    }

    if (options['version'] || options.command?.name == 'version') {
      logger.stdOut('Version 0.4.0');
      return null;
    }

    if (options.command?.name == 'init') {
      final ArgResults initOptions = _initParser.parse(args);
      if (initOptions['help'] == true) {
        logger.stdOut('''
Creates a configuration file `.gitrevision.yaml` to add a fixed config to this project
        
Usage: git revision init [--baseBranch] [--format] [--help] 
        ''');
        logger.stdOut(_initParser.usage);
        return null;
      }

      logger.stdOut('not implemented');
      return null;
    }

    logger.stdErr(
        "unrecognized arguments '${args.join()}', try 'git revision help'");
    throw new ArgError('unrecognized command');
  }
}

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
