#!/usr/bin/env sh


echo "Building git-revision"
pub get
echo "Starting build script"
pub run tool/build.dart