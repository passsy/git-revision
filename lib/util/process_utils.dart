import 'dart:io';

/// Returns stdout of [ProcessResult] or throws if exit `code != 0`
String stdoutText(ProcessResult processResult) {
  if (processResult.exitCode != 0) {
    stderr.writeln("Process finished unexpectly with exitCode: ${processResult.exitCode}");
    stderr.writeln(processResult.stderr);
    throw new Exception(processResult.stderr);
  }
  return processResult.stdout;
}

/// Returns stdout of [ProcessResult] or `null` in case of an error
String stdoutTextOrNull(ProcessResult processResult) {
  if (processResult.exitCode != 0) {
    return null;
  }
  return processResult.stdout;
}
