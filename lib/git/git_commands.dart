class Commit {
  String sha1;
  DateTime date;

  Commit(this.sha1, this.date);

  @override
  String toString() {
    return 'Commit{sha1: ${sha1.substring(0, 7)}, date: ${date
      .millisecondsSinceEpoch}';
  }
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
