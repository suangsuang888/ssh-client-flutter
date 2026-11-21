import 'dart:convert';
import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart';

import '../models/connection_profile.dart';
import 'profile_store.dart';

/// Backs up / restores connection profiles to a WebDAV server.
class WebDavBackup {
  WebDavBackup(this._store);

  final ProfileStore _store;
  static const _fileName = 'profiles.json';

  Client _client(WebDavSettings s) {
    final client = newClient(
      s.url.trim(),
      user: s.username.trim(),
      password: s.password,
    );
    client.setHeaders({'Accept-Charset': 'utf-8'});
    return client;
  }

  String _remotePath(WebDavSettings s) {
    var dir = s.remoteDir.trim();
    if (dir.isEmpty) dir = '/ssh-client-backup';
    if (!dir.startsWith('/')) dir = '/$dir';
    if (dir.endsWith('/')) dir = dir.substring(0, dir.length - 1);
    return '$dir/$_fileName';
  }

  /// Test that the WebDAV server is reachable with the given settings.
  Future<void> testConnection(WebDavSettings s) async {
    final client = _client(s);
    await client.ping();
  }

  /// Upload all profiles to WebDAV. Returns the remote path written.
  Future<String> backup(
    WebDavSettings s,
    List<ConnectionProfile> profiles,
  ) async {
    final client = _client(s);
    final dir = _remotePath(s).replaceAll('/$_fileName', '');
    // Create the directory (ignore error if it already exists).
    try {
      await client.mkdir(dir);
    } catch (_) {}
    final bytes = Uint8List.fromList(utf8.encode(_store.encodeProfiles(profiles)));
    await client.write(_remotePath(s), bytes);
    return _remotePath(s);
  }

  /// Download profiles from WebDAV.
  Future<List<ConnectionProfile>> restore(WebDavSettings s) async {
    final client = _client(s);
    final bytes = await client.read(_remotePath(s));
    final raw = utf8.decode(bytes);
    return _store.decodeProfiles(raw);
  }
}
