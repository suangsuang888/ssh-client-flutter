import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/connection_profile.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.profile});

  final ConnectionProfile? profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _privateKey;
  late final TextEditingController _keyPassphrase;
  late final TextEditingController _startDir;
  AuthType _authType = AuthType.password;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _username = TextEditingController(text: p?.username ?? '');
    _password = TextEditingController(text: p?.password ?? '');
    _privateKey = TextEditingController(text: p?.privateKeyPem ?? '');
    _keyPassphrase = TextEditingController(text: p?.keyPassphrase ?? '');
    _startDir = TextEditingController(text: p?.startDir ?? '');
    _authType = p?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _username,
      _password,
      _privateKey,
      _keyPassphrase,
      _startDir,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles();
    final file = result?.files.single;
    if (file == null) return;
    try {
      String content;
      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return;
      }
      setState(() => _privateKey.text = content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取密钥文件失败：$e')),
      );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.profile;
    final profile = ConnectionProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 22,
      username: _username.text.trim(),
      authType: _authType,
      password: _authType == AuthType.password ? _password.text : null,
      privateKeyPem: _authType == AuthType.key ? _privateKey.text : null,
      keyPassphrase:
          _authType == AuthType.key && _keyPassphrase.text.isNotEmpty
              ? _keyPassphrase.text
              : null,
      startDir: _startDir.text.trim().isEmpty ? null : _startDir.text.trim(),
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? '添加连接' : '编辑连接'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：香港服务器',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: '主机',
                hintText: '域名或 IP（支持 IPv6）',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入主机' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 65535) return '端口无效';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: '用户名'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(
                  value: AuthType.password,
                  label: Text('密码'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: AuthType.key,
                  label: Text('私钥'),
                  icon: Icon(Icons.key_outlined),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (s) => setState(() => _authType = s.first),
            ),
            const SizedBox(height: 16),
            if (_authType == AuthType.password)
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _privateKey,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '私钥（PEM）',
                  hintText: '粘贴 -----BEGIN ... PRIVATE KEY----- 内容',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '请粘贴或导入私钥'
                    : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickKeyFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('从文件导入私钥'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keyPassphrase,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '私钥密码（可选）',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _startDir,
              decoration: const InputDecoration(
                labelText: '文件浏览起始目录（可选）',
                hintText: '留空为家目录，例如 /home/user',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
