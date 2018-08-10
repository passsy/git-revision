import 'dart:async';
import 'dart:io';

import 'package:git_revision/cache.dart';
import 'package:git_revision/git/commit.dart';
import 'package:git_revision/git/local_changes.dart';

/// Access `git` via CLI to gather information about the repo
class GitClient {
  factory GitClient(String workingDir) => _GitClientCache(workingDir);

  GitClient._(this.workingDir);

  String workingDir;

  Future<List<Commit>> revList(String revision, {bool firstParentOnly = false}) async {
    // use commit date not author date. commit date is  the one between the prev and next commit. Author date could be anything
    String result = await git('rev-list --pretty=%cI%n${firstParentOnly ? ' --first-parent' : ''} $revision',
        emptyResultIsError: false);
    if (result == null) return [];

    return result.split('\n\n').where((c) => c.isNotEmpty).map((rawCommit) {
      var lines = rawCommit.split('\n');
      return Commit(lines[0].replaceFirst('commit ', ''), lines[1]);
    }).toList(growable: false);
  }

  /// full Sha1 or `null`
  Future<String> sha1(String revision) async {
    var hash = await git('rev-parse $revision', emptyResultIsError: false);
    if (hash == null) {
      return null;
    }
    assert(() {
      if (hash.isEmpty) throw ArgumentError("sha1 is empty ''");
      if (hash.split('\n').length != 1) throw ArgumentError("sha1 is multiline '$hash'");
      return true;
    }());

    return hash;
  }

  /// branch name of `HEAD` or `null`
  Future<String> get headBranchName async {
    var name = await git('symbolic-ref --short -q HEAD', emptyResultIsError: false);
    if (name == null) return null;

    // empty branch names can't exits this means no branch name
    if (name.isEmpty) return null;

    assert(() {
      if (name.split('\n').length != 1) throw ArgumentError("branch name is multiline '$name'");
      return true;
    }());
    return name;
  }

  Future<LocalChanges> localChanges(String revision) async {
    // TODO move this check outside of GitClient
    if (revision != 'HEAD') {
      // local changes are only interesting for HEAD during active development
      return LocalChanges.NONE;
    }

    var changes = await git('diff --shortstat HEAD', emptyResultIsError: false);
    if (changes == null) return null;
    return _parseDiffShortStat(changes);
  }

  /// returns a Stream of branchNames with prepended remotes where [branchName] exists
  ///
  /// `git branch --all --list "*$rev"`
  Stream<String> branchLocalOrRemote(String branchName) async* {
    String text = await git("branch --all --list *$branchName");
    if (text == null) {
      return;
    }
    var branches = text
        .split('\n')
        // remove asterisk marking the current branch
        .map((it) => it.replaceFirst("* ", ""))
        .map((it) => it.trim());

    for (var branch in branches) {
      yield branch;
    }
  }

  Future<String> git(String args, {bool emptyResultIsError = true}) async {
    var argList = args.split(' ');

    final processResult = await Process.run('git', argList, workingDirectory: workingDir);
    if (processResult.exitCode != 0) {
      return null;
    }
    var text = processResult.stdout as String;
    text = text?.trim();
    if (emptyResultIsError) {
      if (text == null || text.isEmpty) {
        throw ProcessException('git', argList, "returned nothing");
      }
    }
    return text;
  }
}

/// parses the output of `git diff --shortstat`
/// https://github.com/git/git/blob/69e6b9b4f4a91ce90f2c38ed2fa89686f8aff44f/diff.c#L1561
LocalChanges _parseDiffShortStat(String text) {
  if (text == null || text.isEmpty) return LocalChanges.NONE;
  var parts = text.split(",").map((it) => it.trim());

  var filesChanges = 0;
  var additions = 0;
  var deletions = 0;

  for (final part in parts) {
    if (part.contains("changed")) {
      filesChanges = _startingNumber(part) ?? 0;
    }
    if (part.contains("(+)")) {
      additions = _startingNumber(part) ?? 0;
    }
    if (part.contains("(-)")) {
      deletions = _startingNumber(part) ?? 0;
    }
  }
  return LocalChanges(filesChanges, additions, deletions);
}

final _numberRegEx = RegExp("(\\d+).*");

/// returns the int of a string it starts with
int _startingNumber(String text) {
  var match = _numberRegEx.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return int.parse(match.group(1));
  }
  return null;
}

/// Caching layer wrapping the original [GitClient]
class _GitClientCache extends GitClient with FutureCacheMixin {
  _GitClientCache(String workingDir) : super._(workingDir);

  @override
  Future<LocalChanges> localChanges(String revision) =>
      cache(() => super.localChanges(revision), 'localChanges($revision)');

  @override
  Future<String> get headBranchName => cache(() => super.headBranchName, 'headBranchName');

  @override
  Future<String> sha1(String revision) => cache(() => super.sha1(revision), 'sha1($revision)');

  @override
  Future<List<Commit>> revList(String revision, {bool firstParentOnly = false}) {
    var name = 'revList($revision, firstParentOnly=$firstParentOnly)';
    return cache(() => super.revList(revision, firstParentOnly: firstParentOnly), name);
  }

  @override
  Future<String> git(String args, {bool emptyResultIsError: true}) {
    var name = 'git $args -- $emptyResultIsError';
    return cache(() => super.git(args, emptyResultIsError: emptyResultIsError), name);
  }
}
