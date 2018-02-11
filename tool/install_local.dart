import 'dart:async';
import 'dart:io';

Future<Null> main(List<String> args) async {
  var p = await Process.start('pub', ['global', 'activate', '--source', 'path', '.']).then((process) {
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    return process;
  });

  exit(await p.exitCode);
}
