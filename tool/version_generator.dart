import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';
import 'package:dart_style/dart_style.dart';

Builder versionNameBuilder(BuilderOptions options) => PartBuilder([VersionGenerator()]);

class VersionGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    print(buildStep.inputId);
    if (buildStep.inputId.pathSegments.last != 'cli_app.dart') {
      return null;
    }

    var content = await buildStep.readAsString(AssetId(buildStep.inputId.package, 'pubspec.yaml'));

    var yaml = loadYaml(content) as Map;

    var versionString = yaml['version'] as String;

    var dartfmt = DartFormatter();
    return dartfmt.format('''
           const versionName = '$versionString';
           ''');
  }
}
