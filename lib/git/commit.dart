class Commit {
  Commit(this.sha1, this.rawDate);

  String sha1;
  String rawDate;
  DateTime parsedDate;

  DateTime get date {
    try {
      parsedDate ??= DateTime.parse(rawDate);
    } catch (ex, stack) {
      throw Exception("Could not parse commit date '$rawDate'. Is git up-to-date? Minimum git 2.2.0 is required.");
    }
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
