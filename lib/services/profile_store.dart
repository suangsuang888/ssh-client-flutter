import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_profile.dart';

/// Persists connection profiles and WebDAV settings on the device.
class ProfileStore {
  static const _profilesKey = 'ssh_profiles_v1';
  static const _webdavKey = 'webdav_settings_v1';

  Future<List<ConnectionProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConnectionProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<ConnectionProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, raw);
  }

  Future<WebDavSettings> loadWebDavSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webdavKey);
    if (raw == null || raw.isEmpty) return WebDavSettings();
    try {
      return WebDavSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WebDavSettings();
    }
  }

  Future<void> saveWebDavSettings(WebDavSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webdavKey, jsonEncode(settings.toJson()));
  }

  /// Serialize profiles to a JSON string (used for WebDAV backup).
  String encodeProfiles(List<ConnectionProfile> profiles) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'ssh_client',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profiles': profiles.map((p) => p.toJson()).toList(),
    });
  }

  /// Parse profiles from a backup JSON string.
  List<ConnectionProfile> decodeProfiles(String raw) {
    final decoded = jsonDecode(raw);
    final List<dynamic> list;
    if (decoded is Map<String, dynamic> && decoded['profiles'] is List) {
      list = decoded['profiles'] as List<dynamic>;
    } else if (decoded is List) {
      list = decoded;
    } else {
      throw const FormatException('无法识别的备份文件格式');
    }
    return list
        .map((e) => ConnectionProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
