import 'dart:async';
import 'dart:io';

Future<Null> main(List<String> args) async {
  var p0 = await Process.start('pub', ['run', 'build_runner', 'build']).then((process) {
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    return process;
  });

  exitCode = await p0.exitCode;
  if (exitCode > 0) {
    exit(exitCode);
  }

  var p1 = await Process.start('pub', ['global', 'activate', '--source', 'path', '.']).then((process) {
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    return process;
  });

  exit(await p1.exitCode);
}
