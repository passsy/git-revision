import 'dart:async';

import 'package:git_revision/git/git_commands.dart';

class GitVersioner {
  final GitCommands gitCommands;

  GitVersioner(this.gitCommands);

  Future<int> get revision async => 0;

  Future<String> get versionName async => '0.0.0';

  Future<Revision> get branchName async => gitCommands.currentBranch;

  Future<Sha1> get sha1 async => gitCommands.currentSha1;
}
