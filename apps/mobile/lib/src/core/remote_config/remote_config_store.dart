import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Where the last server config and the last verified lexicon bundle are kept
/// between launches. Neither is personal (flags are public, the lexicon ships
/// in the app too), so they live in plain files in the app's support
/// directory — outside the database, which sign-out wipes: a device-level
/// safety resource must survive a sign-out. Every read is checked again
/// before use (the lexicon's signature; the config's shape).
abstract interface class RemoteConfigStore {
  Future<String?> read(String name);
  Future<void> write(String name, String text);
  Future<void> delete(String name);
}

/// Files under `<app support>/remote_config/`. Failures are swallowed: the
/// app then simply uses its bundled defaults.
class FileRemoteConfigStore implements RemoteConfigStore {
  FileRemoteConfigStore(this._root);

  final Future<Directory> Function() _root;

  Future<File> _file(String name) async {
    final dir = Directory('${(await _root()).path}/remote_config');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  @override
  Future<String?> read(String name) async {
    try {
      final f = await _file(name);
      return await f.exists() ? await f.readAsString() : null;
    } on MissingPluginException {
      return null; // no platform (widget tests): the bundled defaults apply
    } on Object catch (e) {
      debugPrint('remote config: read ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(String name, String text) async {
    try {
      final f = await _file(name);
      // Write then rename, so a crash never leaves half a file.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(f.path);
    } on Object catch (e) {
      debugPrint('remote config: write ${e.runtimeType}');
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      final f = await _file(name);
      if (await f.exists()) await f.delete();
    } on Object catch (e) {
      debugPrint('remote config: delete ${e.runtimeType}');
    }
  }
}

/// In memory (tests).
class MemoryRemoteConfigStore implements RemoteConfigStore {
  MemoryRemoteConfigStore([Map<String, String>? initial])
    : files = {...?initial};

  final Map<String, String> files;

  @override
  Future<String?> read(String name) async => files[name];

  @override
  Future<void> write(String name, String text) async => files[name] = text;

  @override
  Future<void> delete(String name) async => files.remove(name);
}
