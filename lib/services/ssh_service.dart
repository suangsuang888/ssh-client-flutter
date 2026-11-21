import 'package:dartssh2/dartssh2.dart';

import '../models/connection_profile.dart';

/// Creates authenticated SSH connections from a [ConnectionProfile].
class SshService {
  /// Connect and authenticate. Throws on failure.
  ///
  /// The caller owns the returned [SSHClient] and must call `close()` on it.
  static Future<SSHClient> connect(ConnectionProfile profile) async {
    final socket = await SSHSocket.connect(profile.host, profile.port);

    List<SSHKeyPair>? identities;
    if (profile.authType == AuthType.key &&
        (profile.privateKeyPem?.trim().isNotEmpty ?? false)) {
      identities = SSHKeyPair.fromPem(
        profile.privateKeyPem!.trim(),
        profile.keyPassphrase,
      );
    }

    final client = SSHClient(
      socket,
      username: profile.username,
      identities: identities,
      onPasswordRequest: () {
        if (profile.authType == AuthType.password) {
          return profile.password ?? '';
        }
        return null;
      },
      // Accept the host key as-is. A production app should verify and
      // remember host keys; kept simple here for a personal tool.
      onVerifyHostKey: (type, fingerprint) async => true,
    );

    // Wait until authentication completes (throws if it fails).
    await client.authenticated;
    return client;
  }
}
