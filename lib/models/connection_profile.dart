/// Authentication method for an SSH connection.
enum AuthType { password, key }

extension AuthTypeX on AuthType {
  String get value => name;
  static AuthType fromValue(String? v) =>
      v == 'key' ? AuthType.key : AuthType.password;
}

/// A saved SSH connection profile.
class ConnectionProfile {
  ConnectionProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authType = AuthType.password,
    this.password,
    this.privateKeyPem,
    this.keyPassphrase,
    this.startDir,
  });

  String id;
  String name;
  String host;
  int port;
  String username;
  AuthType authType;

  /// Used when [authType] is [AuthType.password].
  String? password;

  /// PEM-encoded private key, used when [authType] is [AuthType.key].
  String? privateKeyPem;

  /// Optional passphrase for the private key.
  String? keyPassphrase;

  /// Optional remote directory the file browser opens at.
  String? startDir;

  String get subtitle => '$username@$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'authType': authType.value,
        'password': password,
        'privateKeyPem': privateKeyPem,
        'keyPassphrase': keyPassphrase,
        'startDir': startDir,
      };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String? ?? '',
      authType: AuthTypeX.fromValue(json['authType'] as String?),
      password: json['password'] as String?,
      privateKeyPem: json['privateKeyPem'] as String?,
      keyPassphrase: json['keyPassphrase'] as String?,
      startDir: json['startDir'] as String?,
    );
  }

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    String? privateKeyPem,
    String? keyPassphrase,
    String? startDir,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      keyPassphrase: keyPassphrase ?? this.keyPassphrase,
      startDir: startDir ?? this.startDir,
    );
  }
}

/// WebDAV server settings used for backup / restore.
class WebDavSettings {
  WebDavSettings({
    this.url = '',
    this.username = '',
    this.password = '',
    this.remoteDir = '/ssh-client-backup',
  });

  String url;
  String username;
  String password;

  /// Remote directory that holds the backup file.
  String remoteDir;

  bool get isConfigured => url.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'remoteDir': remoteDir,
      };

  factory WebDavSettings.fromJson(Map<String, dynamic> json) {
    return WebDavSettings(
      url: json['url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remoteDir: json['remoteDir'] as String? ?? '/ssh-client-backup',
    );
  }
}
