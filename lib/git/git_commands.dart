class Commit {
  String sha1;
  DateTime date;

  Commit(this.sha1, this.date);

  @override
  String toString() {
    return 'Commit{sha1: ${sha1.substring(0, 7)}, date: ${date
      .millisecondsSinceEpoch}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Commit && runtimeType == other.runtimeType && sha1 == other.sha1 && date == other.date;

  @override
  int get hashCode => sha1.hashCode ^ date.hashCode;
}

class LocalChanges {
  final int filesChanged;
  final int additions;
  final int deletions;

  static const NONE = const LocalChanges(0, 0, 0);

  const LocalChanges(this.filesChanged, this.additions, this.deletions)
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
