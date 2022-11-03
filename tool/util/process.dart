import 'dart:async';
import 'dart:io';

/// executes the shell command, exits on error
Future<void> sh(String command,
    {bool quiet = false, String? description}) async {
  if (!quiet) print("=> $command");
  final split = command.split(" ");
  final process = await Process.start(split[0], split.skip(1).toList());
  final out = quiet ? Future.value() : stdout.addStream(process.stdout);
  final err = stderr.addStream(process.stderr);
  await Future.wait([out, err]);

  exitCode = await process.exitCode;
  if (exitCode > 0) {
    exit(exitCode);
  }
}
