import 'dart:async';
import 'dart:io' as io;

import 'package:git_revision/cli_app.dart';

Future<void> main(List<String> args) async {
  final app = CliApp.production();

  try {
    await app.process(args);
    io.exit(0);
  } catch (e, st) {
    if (e is ArgError) {
      // These errors are expected.
      io.exit(1);
    } else {
      print('Unexpected error: $e\n$st');
      io.exit(1);
    }
  }
}
