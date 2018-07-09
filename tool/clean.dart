import 'dart:async';

import 'dart:io';

Future<Null> main(List<String> args) async {
  Process p = await Process.start('pub', ['run', 'build_runner', 'clean']).then((process) {
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    return process;
  });

  exit(await p.exitCode);
}
