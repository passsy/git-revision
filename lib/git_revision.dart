import 'dart:async';

class GitVersioner {
  Future<int> revision() async => 0;

  Future<String> versionName() async => '0.0.0';

  Future<String> branchName() async => 'master';
}
