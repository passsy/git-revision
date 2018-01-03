import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

import 'package:args/args.dart';
import 'package:git_revision/git_revision.dart';

class CliApp {
  final CliLogger logger;
  final GitVersioner gitVersioner;

  CliApp(this.gitVersioner, this.logger) : assert(logger != null);

  CliApp.production()
      : gitVersioner = new GitVersioner(),
        logger = new CliLogger();

  final ArgParser _argParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('baseBranch',
        defaultsTo: 'master', help: 'The branch you work on most of the time')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Help!')
    ..addCommand('help')
    ..addFlag('version', abbr: 'v', help: 'Shows version information')
    ..addOption('format', defaultsTo: 'revision', allowed: ['revision (default)', 'more will come...'])
    ..addFlag('test', negatable: false, help: 'TODO: remove'); // TODO remove

  Future process(List<String> args) async {
    var argParser = _argParser;

    ArgResults options;

    try {
      options = argParser.parse(args);
    } catch (e, st) {
      // FormatException: Could not find an option named "foo".
      if (e is FormatException) {
        logger.stdOut('Error: ${e.message}');
        return new Future.error(new ArgError(e.message));
      } else {
        return new Future.error(e, st);
      }
    }

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
      ''');

      logger.stdOut(_argParser.usage);
      return null;
    }

    if (options['test'] == true) {
      logger.stdOut('Result: ${Directory.current.path}');
      return null;
    }

    if (options['version']) {
      logger.stdOut('Version 0.4.0');
      return null;
    }

    return null;
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
