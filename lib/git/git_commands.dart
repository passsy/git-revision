import 'dart:async';

abstract class GitCommands {
  Future<Sha1> get currentSha1;

  Future<Revision> get currentBranch;

  Future<DateTime> initialCommitDate();

  Future<List<Sha1>> commitsToHead();

  Future<DateTime> commitDate(Revision revision);

  Future<List<Sha1>> commitsUpTo(Revision revision, List<String> args);

  Future<LocalChanges> localChanges();
}

class LocalChanges {
  final int filesChanged;
  final int additions;
  final int deletions;

  LocalChanges(this.filesChanged, this.additions, this.deletions)
      : assert(filesChanged >= 0),
        assert(additions >= 0),
        assert(deletions >= 0);

  @override
  String toString() => '$filesChanged +$additions -$deletions';

  String shortStats() {
    if (filesChanged + additions + deletions == 0) {
      return 'no changes';
    } else {
      return 'files changed: $filesChanged, additions(+): $additions, deletions(-): $deletions';
    }
  }
}

class Sha1 {
  final String hash;

  const Sha1(this.hash);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Sha1 && runtimeType == other.runtimeType && hash == other.hash ||
        other is Revision && hash == other.rev;
  }

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() {
    return 'sha1:$hash';
  }
}

class Revision {
  final String rev;

  const Revision(this.rev);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Revision && runtimeType == other.runtimeType && rev == other.rev ||
        other is Sha1 && rev == other.hash;
  }

  @override
  int get hashCode => rev.hashCode;

  @override
  String toString() {
    return 'rev:$rev';
  }
}
