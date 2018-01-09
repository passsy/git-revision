import 'dart:async';
import 'dart:io';

import 'package:git_revision/git/git_commands.dart';

class ShellGitExtractor implements GitCommands {
  @override
  Future<DateTime> commitDate(Revision revision) => _notImplemented();

  @override
  Future<List<Sha1>> commitsToHead() => _notImplemented();

  @override
  Future<List<Sha1>> commitsUpTo(Revision revision, List<String> args) =>
      _notImplemented();

  Future<Revision> _currentBranch;

  @override
  Future<Revision> get currentBranch async => _currentBranch ??= () async {
        await _verifyGitWorking();
        var result =
            await Process.run('git', ['symbolic-ref', '--short', '-q', 'HEAD']);
        var text = (result.stdout as String).trim();
        return new Revision(text);
      }();

  Future<Sha1> _sha1;

  @override
  Future<Sha1> get currentSha1 => _sha1 ??= () async {
        await _verifyGitWorking();
        var result = await Process.run('git', ['rev-parse', 'HEAD']);
        var text = (result.stdout as String).trim();
        return new Sha1(text);
      }();

  @override
  Future<DateTime> initialCommitDate() => _notImplemented();

  @override
  Future<LocalChanges> localChanges() => _notImplemented();

  /// `null` when ready, errors otherwise
  Future<Null> _verifyGitWorking() async => null;
}

Future<T> _notImplemented<T>() => new Future.error(
    new UnimplementedError('Sorry, this feature has not been implemented yet'));
