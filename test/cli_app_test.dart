import 'dart:async';

import 'package:git_revision/cli_app.dart';
import 'package:git_revision/git_revision.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  group('help', () {
    MockLogger logger;
    CliApp app;

    setUp(() async {
      logger = new MockLogger();
      app = new CliApp(logger);
      await app.process(['help']);
    });

    test('shows intro text', () async {
      expect(logger.messages.join(), startsWith('Welcome to git revision'));
    });

    test('shows usage information', () async {
      var usageMessage = logger.messages.join();
      expect(usageMessage, contains('--help'));
      expect(usageMessage, contains('--version'));
      // TODO not implemented yet
      //expect(usageMessage, contains('init'));
    });

    test('all fields are filled', () async {
      for (var msg in logger.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });

  group('empty arguments', () {
    test('has exact same output as help', () async {
      MockLogger logger1 = new MockLogger();
      CliApp app1 = new CliApp(logger1);
      await app1.process(['help']);

      MockLogger logger2 = new MockLogger();
      CliApp app2 = new CliApp(logger2);
      await app2.process([]);

      expect(logger1.messages, equals(logger2.messages));
      expect(logger1.errors, equals(logger2.errors));
    });
  });

  group('--help', () {
    test('has exact same output as help', () async {
      MockLogger logger1 = new MockLogger();
      CliApp app1 = new CliApp(logger1);
      await app1.process(['help']);

      MockLogger logger2 = new MockLogger();
      CliApp app2 = new CliApp(logger2);
      await app2.process(['--help']);

      expect(logger1.messages, equals(logger2.messages));
      expect(logger1.errors, equals(logger2.errors));
    });
  });

  group('version', () {
    MockLogger logger;
    CliApp app;

    setUp(() async {
      logger = new MockLogger();
      app = new CliApp(logger);
      await app.process(['version']);
    });

    test('shows version number', () async {
      expect(logger.messages, hasLength(1));
      expect(logger.messages[0], contains('Version'));

      // contains a semantic version string (simplified)
      var semanticVersion = new RegExp(r'.*\d{1,3}\.\d{1,3}\.\d{1,3}.*');
      expect(semanticVersion.hasMatch(logger.messages[0]), true);
    });

    test('all fields are filled', () async {
      for (var msg in logger.messages) {
        expect(msg, isNot(contains('null')));
      }
    });
  });

  group('--version', () {
    test('has exact same output as version', () async {
      MockLogger logger1 = new MockLogger();
      CliApp app1 = new CliApp(logger1);
      await app1.process(['version']);

      MockLogger logger2 = new MockLogger();
      CliApp app2 = new CliApp(logger2);
      await app2.process(['--version']);

      expect(logger1.messages, equals(logger2.messages));
      expect(logger1.errors, equals(logger2.errors));
    });

    test('with known command --version shows command output', () async {
      MockLogger logger1 = new MockLogger();
      CliApp app1 = new CliApp(logger1);
      await app1.process(['help']);

      MockLogger logger2 = new MockLogger();
      CliApp app2 = new CliApp(logger2);
      await app2.process(['help', '--version']);

      expect(logger1.messages, equals(logger2.messages));
      expect(logger1.errors, equals(logger2.errors));
    });
  });

  group('revision', () {
    MockLogger logger;
    CliApp app;
    GitVersioner versioner;
    String log;

    setUp(() async {
      logger = new MockLogger();
      versioner = new MockGitVersioner();
      when(versioner.revision).thenReturn(new Future.value('432'));
      when(versioner.versionName).thenReturn(new Future.value('432-SNAPSHOT'));
      when(versioner.branchName).thenReturn(new Future.value('myBranch'));
      when(versioner.sha1).thenReturn(new Future.value('1234567'));

      app = new CliApp(logger);
      app.versionerProvider = (config) => versioner;
      await app.process(['revision']);
      log = logger.messages.join('\n');
    });

    test('shows revision', () async {
      expect(log, contains('Revision: 432'));
    });

    test('shows version name', () async {
      expect(log, contains('Version name: 432-SNAPSHOT'));
    });

    test('shows branch', () async {
      expect(log, contains('myBranch'));
    });
    test('shows sha1', () async {
      expect(log, contains('1234567'));
    });

    test('all fields are filled', () async {
      expect(log, isNot(contains('null')));
    });

    test('requires gitVersioner', () async {
      app = new CliApp(new MockLogger());
      try {
        await app.process([]);
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('gitVersioner'));
      }
    });
  });

  group('init', () {
    //TODO
  });

  group('construct app', () {
    test("logger can't be null", () {
      try {
        new CliApp(null);
      } on AssertionError catch (e) {
        expect(e.toString(), contains('logger != null'));
      }
    });
  });
}

class MockGitVersioner extends Mock implements GitVersioner {}

class MockLogger extends CliLogger {
  List<String> messages = [];
  List<String> errors = [];

  @override
  void stdOut(String s) => messages.add(s);

  @override
  void stdErr(String s) => errors.add(s);
}
