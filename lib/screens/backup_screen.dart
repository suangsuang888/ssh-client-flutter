import 'package:flutter/material.dart';

import '../models/connection_profile.dart';
import '../services/profile_store.dart';
import '../services/webdav_backup.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.profiles,
    required this.onRestored,
  });

  final List<ConnectionProfile> profiles;
  final Future<void> Function(List<ConnectionProfile>) onRestored;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _store = ProfileStore();
  late final WebDavBackup _backup = WebDavBackup(_store);
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _remoteDir = TextEditingController(text: '/ssh-client-backup');
  bool _busy = false;
  bool _obscure = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _store.loadWebDavSettings();
    if (!mounted) return;
    setState(() {
      _url.text = s.url;
      _username.text = s.username;
      _password.text = s.password;
      _remoteDir.text = s.remoteDir;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _remoteDir.dispose();
    super.dispose();
  }

  WebDavSettings _current() => WebDavSettings(
        url: _url.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        remoteDir: _remoteDir.text.trim(),
      );

  Future<void> _run(Future<void> Function(WebDavSettings) action) async {
    final s = _current();
    if (!s.isConfigured) {
      setState(() => _status = '请先填写 WebDAV 地址');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await _store.saveWebDavSettings(s);
      await action(s);
    } catch (e) {
      if (mounted) setState(() => _status = '失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 备份 / 恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '把全部连接配置备份到你的 WebDAV 服务器，换设备时可恢复。'
            '备份文件包含密码/私钥，请确保 WebDAV 服务器可信。',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'WebDAV 地址',
              hintText: 'https://dav.example.com/dav',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '密码',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remoteDir,
            decoration: const InputDecoration(
              labelText: '远程目录',
              hintText: '/ssh-client-backup',
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run((s) async {
                          await _backup.testConnection(s);
                          if (mounted) setState(() => _status = '连接正常');
                        }),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('测试连接'),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run((s) async {
                          final path =
                              await _backup.backup(s, widget.profiles);
                          if (mounted) {
                            setState(
                              () => _status =
                                  '已备份 ${widget.profiles.length} 个连接到 $path',
                            );
                          }
                        }),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('备份'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run((s) async {
                          final restored = await _backup.restore(s);
                          await widget.onRestored(restored);
                          if (mounted) {
                            setState(
                              () => _status = '已恢复 ${restored.length} 个连接',
                            );
                          }
                        }),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('恢复'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 20),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
