import 'dart:io';

/// Returns stdout of [ProcessResult] or throws if exit `code != 0`
String stdoutText(ProcessResult processResult) {
  if (processResult.exitCode != 0) {
    stderr.write("Exit code: ${processResult.exitCode}");
    stderr.write(processResult.stderr);
    throw new Exception(processResult.stderr);
  }
  return processResult.stdout;
}
