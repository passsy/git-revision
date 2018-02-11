import 'package:collection/collection.dart';
import 'package:git_revision/cli_app.dart';

/// [CliLogger] which stores all messages accessible in memory
class MemoryLogger extends CliLogger {
  List<String> messages = [];
  List<String> errors = [];

  @override
  void stdOut(String s) => messages.add(s);

  @override
  void stdErr(String s) => errors.add(s);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MemoryLogger &&
              runtimeType == other.runtimeType &&
              const IterableEquality().equals(messages, other.messages) &&
              const IterableEquality().equals(errors, other.errors);

  @override
  int get hashCode => const IterableEquality().hash(messages) ^ const IterableEquality().hash(errors);

  @override
  String toString() {
    return 'MockLogger{messages: $messages, errors: $errors}';
  }
}