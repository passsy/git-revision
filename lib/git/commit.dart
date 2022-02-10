class Commit {
  Commit(this.sha1, this.rawDate);

  String sha1;
  String rawDate;
  DateTime? parsedDate;

  DateTime get date {
    return parsedDate ??= DateTime.fromMillisecondsSinceEpoch(int.parse(rawDate) * 1000);
  }

  @override
  String toString() {
    return 'Commit{sha1: ${sha1.substring(0, 7)}, date: $rawDate';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Commit && runtimeType == other.runtimeType && sha1 == other.sha1;

  @override
  int get hashCode => sha1.hashCode;
}
