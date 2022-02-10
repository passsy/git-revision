import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// The version of git_revision.
Future<String> projectVersion() async {
  final content = await File('pubspec.yaml').readAsString();
  final yaml = loadYaml(content) as Map;
  final version = yaml['version'] as String;
  assert(version.isNotEmpty);
  return version;
}
