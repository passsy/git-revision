import 'dart:async';

import 'package:git_revision/cli_app.dart';
import 'package:git_revision/git/commit.dart';
import 'package:git_revision/git/git_client.dart';
import 'package:git_revision/git/local_changes.dart';
import 'package:git_revision/git_revision.dart';
import 'package:test/test.dart';

import 'util/memory_logger.dart';

void main() {
  group('parse args', () {
    group('help', () {
      test('default', () async {
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.showHelp, false);
      });
      test('add flag', () async {
        final parsed = CliApp.parseCliArgs(['--help']);
        expect(parsed.showHelp, true);
      });
      test('add flag #2', () async {
        final parsed = CliApp.parseCliArgs(['-h']);
        expect(parsed.showHelp, true);
      });
    });

    group('version', () {
      test('default', () async {
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.showVersion, false);
      });
      test('add flag', () async {
        final parsed = CliApp.parseCliArgs(['--version']);
        expect(parsed.showVersion, true);
      });
      test('add flag #2', () async {
        final parsed = CliApp.parseCliArgs(['-v']);
        expect(parsed.showVersion, true);
      });
    });

    group('context', () {
      test('default', () async {
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.repoPath, null);
      });

      test('set context', () async {
        final parsed = CliApp.parseCliArgs(['--context', '../Other Project/']);
        expect(parsed.repoPath, '../Other Project/');
      });
      test('set context #2', () async {
        final parsed = CliApp.parseCliArgs(['--context=../Other Project/']);
        expect(parsed.repoPath, '../Other Project/');
      });

      test('set context with abbr', () async {
        final parsed = CliApp.parseCliArgs(['-C', '../Other Project/']);
        expect(parsed.repoPath, '../Other Project/');
      });

      test('set context with abbr #2', () async {
        final parsed = CliApp.parseCliArgs(['-C../Other Project/']);
        expect(parsed.repoPath, '../Other Project/');
      });
    });

    group('baseBranch', () {
      test('default', () async {
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.baseBranch, isNull);
      });

      test('set baseBranch', () async {
        final parsed = CliApp.parseCliArgs(['--baseBranch', 'develop']);
        expect(parsed.baseBranch, 'develop');
      });
      test('set baseBranch #2', () async {
        final parsed = CliApp.parseCliArgs(['--baseBranch=develop']);
        expect(parsed.baseBranch, 'develop');
      });

      test('set baseBranch with abbr', () async {
        final parsed = CliApp.parseCliArgs(['-b', 'develop']);
        expect(parsed.baseBranch, 'develop');
      });

      test('set baseBranch with abbr #2', () async {
        final parsed = CliApp.parseCliArgs(['-bdevelop']);
        expect(parsed.baseBranch, 'develop');
      });
    });

    test('set stopDebounce', () async {
      final parsed = CliApp.parseCliArgs(['-d 1200']);
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
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.yearFactor, GitVersioner.defaultYearFactor);
      });

      test('set yearFactor', () async {
        final parsed = CliApp.parseCliArgs(['--yearFactor', '1200']);
        expect(parsed.yearFactor, 1200);
      });
      test('set yearFactor #2', () async {
        final parsed = CliApp.parseCliArgs(['--yearFactor=1200']);
        expect(parsed.yearFactor, 1200);
      });

      test('set yearFactor with abbr', () async {
        final parsed = CliApp.parseCliArgs(['-y', '1200']);
        expect(parsed.yearFactor, 1200);
      });

      test('set yearFactor with abbr #2', () async {
        final parsed = CliApp.parseCliArgs(['-y1200']);
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
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.stopDebounce, GitVersioner.defaultStopDebounce);
      });

      test('set stopDebounce', () async {
        final parsed = CliApp.parseCliArgs(['--stopDebounce', '96']);
        expect(parsed.stopDebounce, 96);
      });
      test('set stopDebounce #2', () async {
        final parsed = CliApp.parseCliArgs(['--stopDebounce=96']);
        expect(parsed.stopDebounce, 96);
      });

      test('set stopDebounce with abbr', () async {
        final parsed = CliApp.parseCliArgs(['-d', '96']);
        expect(parsed.stopDebounce, 96);
      });

      test('set stopDebounce with abbr #2', () async {
        final parsed = CliApp.parseCliArgs(['-d96']);
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
        final parsed = CliApp.parseCliArgs(['']);
        expect(parsed.revision, 'HEAD');
      });

      test('set rev', () async {
        final parsed = CliApp.parseCliArgs(['someBranch']);
        expect(parsed.revision, 'someBranch');
      });

      test('set rev before options', () async {
        final parsed = CliApp.parseCliArgs(['someBranch', '--baseBranch=asdf']);
        expect(parsed.revision, 'someBranch');
      });

      test('set rev after options', () async {
        final parsed = CliApp.parseCliArgs(['--baseBranch=asdf', 'someBranch']);
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
    late MemoryLogger output;

    setUp(() async {
      output = await _gitRevision("--help");
    });

    test('shows intro text', () async {
      expect(
        output.messages.join(),
        startsWith(
            "git revision creates a useful revision for your project beyond 'git describe'"),
      );
    });

    test('shows usage information', () async {
      final usageMessage = output.messages.join();
      expect(usageMessage, contains('--help'));
      expect(usageMessage, contains('--version'));
    });

    test('all fields are filled', () async {
      for (final msg in output.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });

  group('--version', () {
    late MemoryLogger output;

    setUp(() async {
      output = await _gitRevision("--version");
    });

    test('shows version number', () async {
      expect(output.messages, hasLength(1));
      expect(output.messages[0], contains('Version'));

      // contains a semantic version string (simplified)
      final semanticVersion = RegExp(r'.*\d{1,3}\.\d{1,3}\.\d{1,3}.*');
      expect(semanticVersion.hasMatch(output.messages[0]), true);
    });

    test('all fields are filled', () async {
      for (final msg in output.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });
  group('global args order', () {
    test('--help outranks --version', () async {
      final version = await _gitRevision("--help");
      final both = await _gitRevision("--version --help");
      expect(both, equals(version));
    });

    test('--help outranks revision', () async {
      final version = await _gitRevision("--help");
      final both = await _gitRevision("HEAD --help");
      expect(both, equals(version));
    });

    test('--version outranks revision', () async {
      final version = await _gitRevision("--version");
      final both = await _gitRevision("HEAD --version");
      expect(both, equals(version));
    });
  });

  group('--full', () {
    MemoryLogger logger;
    CliApp app;
    late String log;

    setUp(() async {
      logger = MemoryLogger();

      app = CliApp(logger, (config) {
        return _FakeGitVersioner(
          config: config,
          revisionField: 432,
          versionNameField: '432-SNAPSHOT',
          headBranchNameField: 'myBranch',
          sha1Field: '1234567',
          allFirstBaseBranchCommitsField: _commits(152),
          commitsField: _commits(432),
          baseBranchCommitsField: _commits(377),
          baseBranchTimeComponentField: 773,
          featureBranchCommitsField: _commits(677),
          featureBranchTimeComponentField: 776,
          featureBranchOriginField: Commit('featureBranchOrigin', '0'),
          localChangesField: const LocalChanges(4, 5, 6),
          baseBranchField: 'notmain',
        );
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

    test('baseBranch', () async {
      expect(log, contains('baseBranch: notmain'));
    });
  });
}

Future<MemoryLogger> _gitRevision(String args) async {
  final logger = MemoryLogger();
  // creates CliApp without revision part
  final app = CliApp(logger, (_) => null);

  await app.process(args.split(' '));

  return logger;
}

class _FakeGitVersioner implements GitVersioner {
  _FakeGitVersioner({
    this.allFirstBaseBranchCommitsField,
    this.baseBranchCommitsField,
    this.baseBranchTimeComponentField,
    this.commitsField,
    required this.config,
    this.featureBranchCommitsField,
    this.featureBranchOriginField,
    this.featureBranchTimeComponentField,
    this.headBranchNameField,
    this.localChangesField,
    this.revisionField,
    this.sha1Field,
    this.versionNameField,
    this.baseBranchField,
  });

  final List<Commit>? allFirstBaseBranchCommitsField;
  @override
  Future<List<Commit>> get allFirstBaseBranchCommits async =>
      allFirstBaseBranchCommitsField!;

  final List<Commit>? baseBranchCommitsField;
  @override
  Future<List<Commit>> get baseBranchCommits async => baseBranchCommitsField!;

  final int? baseBranchTimeComponentField;
  @override
  Future<int> get baseBranchTimeComponent async =>
      baseBranchTimeComponentField!;
  final List<Commit>? commitsField;
  @override
  Future<List<Commit>> get commits async => commitsField!;

  @override
  final GitVersionerConfig config;

  List<Commit>? featureBranchCommitsField;
  @override
  Future<List<Commit>> get featureBranchCommits async =>
      featureBranchCommitsField!;

  Commit? featureBranchOriginField;
  @override
  Future<Commit?> get featureBranchOrigin async => featureBranchOriginField;

  int? featureBranchTimeComponentField;
  @override
  Future<int> get featureBranchTimeComponent async =>
      featureBranchTimeComponentField!;

  @override
  GitClient get gitClient => throw UnimplementedError();

  String? headBranchNameField;
  @override
  Future<String?> get headBranchName async => headBranchNameField!;

  LocalChanges? localChangesField;
  @override
  Future<LocalChanges?> get localChanges async => localChangesField!;

  int? revisionField;
  @override
  Future<int> get revision async => revisionField!;

  String? sha1Field;
  @override
  Future<String?> get sha1 async => sha1Field;

  String? versionNameField;

  @override
  Future<String> get versionName async => versionNameField!;

  String? baseBranchField;
  @override
  Future<String> get baseBranch async => baseBranchField!;
}

List<Commit> _commits(int count) {
  final now = DateTime.now();
  return List.generate(count, (_) {
    return Commit("some sha1", now.toIso8601String());
  }).toList(growable: false);
}
