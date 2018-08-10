import 'dart:async';

import 'package:git_revision/cli_app.dart';
import 'package:git_revision/git/commit.dart';
import 'package:git_revision/git/local_changes.dart';
import 'package:git_revision/git_revision.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'util/memory_logger.dart';

void main() {
  group('parse args', () {
    group('help', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.showHelp, false);
      });
      test('add flag', () async {
        var parsed = CliApp.parseCliArgs(['--help']);
        expect(parsed.showHelp, true);
      });
      test('add flag #2', () async {
        var parsed = CliApp.parseCliArgs(['-h']);
        expect(parsed.showHelp, true);
      });
    });

    group('version', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.showVersion, false);
      });
      test('add flag', () async {
        var parsed = CliApp.parseCliArgs(['--version']);
        expect(parsed.showVersion, true);
      });
      test('add flag #2', () async {
        var parsed = CliApp.parseCliArgs(['-v']);
        expect(parsed.showVersion, true);
      });
    });

    group('context', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.repoPath, null);
      });

      test('set context', () async {
        var parsed = CliApp.parseCliArgs(['--context', '../Other\ Project/']);
        expect(parsed.repoPath, '../Other\ Project/');
      });
      test('set context #2', () async {
        var parsed = CliApp.parseCliArgs(['--context=../Other\ Project/']);
        expect(parsed.repoPath, '../Other\ Project/');
      });

      test('set context with abbr', () async {
        var parsed = CliApp.parseCliArgs(['-C', '../Other\ Project/']);
        expect(parsed.repoPath, '../Other\ Project/');
      });

      test('set context with abbr #2', () async {
        var parsed = CliApp.parseCliArgs(['-C../Other\ Project/']);
        expect(parsed.repoPath, '../Other\ Project/');
      });
    });

    group('baseBranch', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.baseBranch, GitVersioner.DEFAULT_BRANCH);
      });

      test('set baseBranch', () async {
        var parsed = CliApp.parseCliArgs(['--baseBranch', 'develop']);
        expect(parsed.baseBranch, 'develop');
      });
      test('set baseBranch #2', () async {
        var parsed = CliApp.parseCliArgs(['--baseBranch=develop']);
        expect(parsed.baseBranch, 'develop');
      });

      test('set baseBranch with abbr', () async {
        var parsed = CliApp.parseCliArgs(['-b', 'develop']);
        expect(parsed.baseBranch, 'develop');
      });

      test('set baseBranch with abbr #2', () async {
        var parsed = CliApp.parseCliArgs(['-bdevelop']);
        expect(parsed.baseBranch, 'develop');
      });
    });

    test('set stopDebounce', () async {
      var parsed = CliApp.parseCliArgs(['-d 1200']);
      expect(parsed.stopDebounce, 1200);
    });

    test('report invalid stopDebounce format ', () async {
      try {
        CliApp.parseCliArgs(['-d asdf']);
        fail('did not throw');
      } on ArgError catch (e, _) {
        expect(e.message, contains("stopDebounce"));
        expect(e.message, contains("'asdf'"));
      }
    });

    group('yearFactor', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.yearFactor, GitVersioner.DEFAULT_YEAR_FACTOR);
      });

      test('set yearFactor', () async {
        var parsed = CliApp.parseCliArgs(['--yearFactor', '1200']);
        expect(parsed.yearFactor, 1200);
      });
      test('set yearFactor #2', () async {
        var parsed = CliApp.parseCliArgs(['--yearFactor=1200']);
        expect(parsed.yearFactor, 1200);
      });

      test('set yearFactor with abbr', () async {
        var parsed = CliApp.parseCliArgs(['-y', '1200']);
        expect(parsed.yearFactor, 1200);
      });

      test('set yearFactor with abbr #2', () async {
        var parsed = CliApp.parseCliArgs(['-y1200']);
        expect(parsed.yearFactor, 1200);
      });

      test('report invalid yearFactor format ', () async {
        try {
          CliApp.parseCliArgs(['--yearFactor=asdf']);
          fail('did not throw');
        } on ArgError catch (e, _) {
          expect(e.message, contains("yearFactor"));
          expect(e.message, contains("'asdf'"));
        }
      });
    });

    group('stopDebounce', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.stopDebounce, GitVersioner.DEFAULT_STOP_DEBOUNCE);
      });

      test('set stopDebounce', () async {
        var parsed = CliApp.parseCliArgs(['--stopDebounce', '96']);
        expect(parsed.stopDebounce, 96);
      });
      test('set stopDebounce #2', () async {
        var parsed = CliApp.parseCliArgs(['--stopDebounce=96']);
        expect(parsed.stopDebounce, 96);
      });

      test('set stopDebounce with abbr', () async {
        var parsed = CliApp.parseCliArgs(['-d', '96']);
        expect(parsed.stopDebounce, 96);
      });

      test('set stopDebounce with abbr #2', () async {
        var parsed = CliApp.parseCliArgs(['-d96']);
        expect(parsed.stopDebounce, 96);
      });

      test('report invalid stopDebounce format ', () async {
        try {
          CliApp.parseCliArgs(['--stopDebounce=asdf']);
          fail('did not throw');
        } on ArgError catch (e, _) {
          expect(e.message, contains("stopDebounce"));
          expect(e.message, contains("'asdf'"));
        }
      });
    });

    group('revision', () {
      test('default', () async {
        var parsed = CliApp.parseCliArgs(['']);
        expect(parsed.revision, 'HEAD');
      });

      test('set rev', () async {
        var parsed = CliApp.parseCliArgs(['someBranch']);
        expect(parsed.revision, 'someBranch');
      });

      test('set rev before options', () async {
        var parsed = CliApp.parseCliArgs(['someBranch', '--baseBranch=asdf']);
        expect(parsed.revision, 'someBranch');
      });

      test('set rev after options', () async {
        var parsed = CliApp.parseCliArgs(['--baseBranch=asdf', 'someBranch']);
        expect(parsed.revision, 'someBranch');
      });

      test('multiple revs throw', () async {
        try {
          CliApp.parseCliArgs(['someBranch', 'otherBranch']);
          fail('did not throw');
        } on ArgError catch (e, _) {
          expect(e.message, contains("[someBranch, otherBranch]"));
        }
      });
    });
  });

  group('--help', () {
    MemoryLogger output;

    setUp(() async {
      output = await _gitRevision("--help");
    });

    test('shows intro text', () async {
      expect(output.messages.join(),
          startsWith("git revision creates a useful revision for your project beyond 'git describe'"));
    });

    test('shows usage information', () async {
      var usageMessage = output.messages.join();
      expect(usageMessage, contains('--help'));
      expect(usageMessage, contains('--version'));
    });

    test('all fields are filled', () async {
      for (var msg in output.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });

  group('--version', () {
    MemoryLogger output;

    setUp(() async {
      output = await _gitRevision("--version");
    });

    test('shows version number', () async {
      expect(output.messages, hasLength(1));
      expect(output.messages[0], contains('Version'));

      // contains a semantic version string (simplified)
      var semanticVersion = new RegExp(r'.*\d{1,3}\.\d{1,3}\.\d{1,3}.*');
      expect(semanticVersion.hasMatch(output.messages[0]), true);
    });

    test('all fields are filled', () async {
      for (var msg in output.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });
  group('global args order', () {
    test('--help outranks --version', () async {
      var version = await _gitRevision("--help");
      var both = await _gitRevision("--version --help");
      expect(both, equals(version));
    });

    test('--help outranks revision', () async {
      var version = await _gitRevision("--help");
      var both = await _gitRevision("HEAD --help");
      expect(both, equals(version));
    });

    test('--version outranks revision', () async {
      var version = await _gitRevision("--version");
      var both = await _gitRevision("HEAD --version");
      expect(both, equals(version));
    });
  });

  group('--full', () {
    MemoryLogger logger;
    CliApp app;
    GitVersioner versioner;
    String log;

    setUp(() async {
      logger = new MemoryLogger();

      app = new CliApp(logger, (config) {
        versioner = new _MockGitVersioner();
        when(versioner.config).thenReturn(config);
        when(versioner.revision).thenAnswer((_) => new Future.value(432));
        when(versioner.versionName).thenAnswer((_) => new Future.value('432-SNAPSHOT'));
        when(versioner.headBranchName).thenAnswer((_) => new Future.value('myBranch'));
        when(versioner.sha1).thenAnswer((_) => new Future.value('1234567'));
        when(versioner.allFirstBaseBranchCommits).thenAnswer((_) => new Future.value(_commits(152)));
        when(versioner.baseBranchCommits).thenAnswer((_) => new Future.value(_commits(377)));
        when(versioner.baseBranchTimeComponent).thenAnswer((_) => new Future.value(773));
        when(versioner.featureBranchCommits).thenAnswer((_) => new Future.value(_commits(677)));
        when(versioner.featureBranchTimeComponent).thenAnswer((_) => new Future.value(776));
        when(versioner.featureBranchOrigin)
            .thenAnswer((_) => new Future.value(new Commit('featureBranchOrigin', null)));
        when(versioner.commits).thenAnswer((_) => new Future.value(_commits(432)));
        when(versioner.localChanges).thenAnswer((_) => new Future.value(LocalChanges(4, 5, 6)));
        return versioner;
      });
      await app.process(['-y 100', 'HEAD', '--baseBranch', 'asdf', '--full']);
      log = logger.messages.join('\n');
    });

    test('shows revision', () async {
      expect(log, contains('versionCode: 432'));
    });

    test('shows version name', () async {
      expect(log, contains('versionName: 432-SNAPSHOT'));
    });

    test('shows current branch', () async {
      expect(log, contains('myBranch'));
    });

    test('shows featureBranchOrigin', () async {
      expect(log, contains('featureOrigin: featureBranchOrigin'));
    });

    test('shows base branch', () async {
      expect(log, contains('baseBranch'));
    });

    test('shows complete first-only base branch commit count', () async {
      expect(log, contains('completeFirstOnlyBaseBranchCommitCount: 152'));
    });

    test('shows sha1', () async {
      expect(log, contains('1234567'));
    });

    test('shows base branch time commits', () async {
      expect(log, contains('377'));
    });

    test('shows base branch time component', () async {
      expect(log, contains('773'));
    });

    test('shows feature branch time commits', () async {
      expect(log, contains('677'));
    });

    test('shows feature branch time component', () async {
      expect(log, contains('776'));
    });

    test('shows local changes', () async {
      expect(log, contains('4 +5 -6'));
    });

    test('all fields are filled', () async {
      // detects new added fields which aren't mocked
      expect(log, isNot(contains('null')));
    });

    test('requires gitVersioner', () async {
      app = new CliApp(new MemoryLogger(), (_) => null);
      try {
        await app.process([]);
      } on AssertionError catch (e) {
        expect(e.toString(), contains('versioner != null'));
      }
    });
  });

  group('initialize cli app', () {
    test("logger can't be null", () {
      try {
        new CliApp(null, null);
      } on AssertionError catch (e) {
        expect(e.toString(), contains('logger != null'));
      }
    });
  });
}

Future<MemoryLogger> _gitRevision(String args) async {
  var logger = new MemoryLogger();
  // creates CliApp without revision part
  var app = new CliApp(logger, (_) => null);

  await app.process(args.split(' '));

  return logger;
}

class _MockGitVersioner extends Mock implements GitVersioner {}

List<Commit> _commits(int count) {
  var now = new DateTime.now();
  return new List(count).map((_) {
    return new Commit("some sha1", now.toIso8601String());
  }).toList(growable: false);
}
