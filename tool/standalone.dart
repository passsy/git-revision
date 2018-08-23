// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import 'build.dart';
import 'util/archive.dart';
import 'util/utils.dart';

/// Generates the standalone packages
Future<Null> main(List<String> args) => standalone();

/// Big thanks to @nex3 and the https://github.com/sass/dart-sass project where the this process first appeared
Future<Null> standalone() async {
  await build();

  final platforms = ["linux", "macos", "windows"];
  final architectures = ["ia32", "x64"];
  final Version dartVersion = Version.parse(Platform.version.split(" ").first);
  String channel = dartVersion.isPreRelease ? "dev" : "stable";
  await Future.wait(platforms.expand((os) {
    return architectures.map((arch) {
      return StandaloneBundler(os, arch, dartVersion.toString(), channel).bundle();
    });
  }));
}

class StandaloneBundler {
  final String os;
  final String architecture;
  final String channel;
  final String dartVersion;

  StandaloneBundler(this.os, this.architecture, this.dartVersion, this.channel);

  Future bundle() async {
    final sdk = await _downloadDartSdk();
    final archive = await _bundleArchive(sdk);
    await _writeToDisk(archive);
  }

  Future<Archive> _downloadDartSdk() async {
    // TODO: Compile a single executable that embeds the Dart VM and the snapshot
    // when dart-lang/sdk#27596 is fixed.
    final url = "https://storage.googleapis.com/dart-archive/channels/$channel/"
        "release/$dartVersion/sdk/dartsdk-$os-$architecture-release.zip";
    print("Downloading $url...");
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw "Failed to download package: ${response.statusCode} ${response.reasonPhrase}.";
    }
    final dartSdk = ZipDecoder().decodeBytes(response.bodyBytes);
    return dartSdk;
  }

  Future<Archive> _bundleArchive(Archive dartSdk) async {
    final archive = Archive();

    // add dart executable
    if (os == 'windows') {
      final dart = dartSdk.firstWhere((file) => file.name.endsWith("/bin/dart.exe")).content as List<int>;
      archive.addFile(fileFromBytes("git-revision/src/dart.exe", dart, executable: true));
    } else {
      final dart = dartSdk.firstWhere((file) => file.name.endsWith("/bin/dart")).content as List<int>;
      archive.addFile(fileFromBytes("git-revision/src/dart", dart, executable: true));
    }

    // and the dart license
    archive.addFile(fileFromBytes(
        "git-revision/src/DART_LICENSE", dartSdk.firstWhere((file) => file.name.endsWith("/LICENSE")).content));

    // add snapshot
    // TODO: Use an app snapshots when https://github.com/dart-lang/sdk/issues/28617 is fixed.
    archive.addFile(file("git-revision/src/git_revision.dart.snapshot", "build/git_revision.dart.snapshot"));
    // and the project license
    archive.addFile(file("git-revision/src/LICENSE", "LICENSE"));

    // add executable
    archive.addFile(file("git-revision/git-revision", "package/git-revision.sh", executable: true));
    archive.addFile(file("git-revision/git-revision.bat", "package/git-revision.bat", executable: true));

    return archive;
  }

  Future<void> _writeToDisk(final Archive archive) async {
    final version = await projectVersion();
    final prefix = 'build/git_revision-$version-$os-$architecture';
    if (os == 'windows') {
      final output = "$prefix.zip";
      print("Saving $output...");
      await File(output).writeAsBytes(ZipEncoder().encode(archive));
    } else {
      final output = "$prefix.tar.gz";
      print("Saving $output...");
      await File(output).writeAsBytes(GZipEncoder().encode(TarEncoder().encode(archive)));
    }
  }
}
