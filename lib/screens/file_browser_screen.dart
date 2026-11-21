import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/connection_profile.dart';
import '../services/ssh_service.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key, required this.profile});

  final ConnectionProfile profile;

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  SSHClient? _client;
  SftpClient? _sftp;
  String _cwd = '/';
  List<SftpName> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = await SshService.connect(widget.profile);
      _client = client;
      _sftp = await client.sftp();
      var start = widget.profile.startDir;
      if (start == null || start.isEmpty) {
        start = await _sftp!.absolute('.');
      }
      _cwd = start;
      await _list(_cwd);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '连接失败：$e';
      });
    }
  }

  Future<void> _list(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _sftp!.listdir(path);
      items.removeWhere((e) => e.filename == '.' || e.filename == '..');
      items.sort((a, b) {
        final ad = a.attr.isDirectory, bd = b.attr.isDirectory;
        if (ad != bd) return ad ? -1 : 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _cwd = path;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取目录失败：$e';
      });
    }
  }

  String _join(String dir, String name) {
    if (dir.endsWith('/')) return '$dir$name';
    return '$dir/$name';
  }

  void _goUp() {
    if (_cwd == '/') return;
    var parent = p.posix.dirname(_cwd);
    if (parent.isEmpty) parent = '/';
    _list(parent);
  }

  Future<void> _download(SftpName item) async {
    final remote = _join(_cwd, item.filename);
    try {
      final file = await _sftp!.open(remote);
      final bytes = await file.readBytes();
      await file.close();
      final dir = await getApplicationDocumentsDirectory();
      final local = File(p.join(dir.path, item.filename));
      await local.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已下载到 ${local.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$e')),
      );
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles();
    final picked = result?.files.single;
    if (picked == null) return;
    try {
      List<int> bytes;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        return;
      }
      final remote = _join(_cwd, picked.name);
      final file = await _sftp!.open(
        remote,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      await file.writeBytes(Uint8List.fromList(bytes));
      await file.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已上传 ${picked.name}')),
      );
      await _list(_cwd);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败：$e')),
      );
    }
  }

  Future<void> _mkdir() async {
    final name = await _promptText('新建文件夹', '文件夹名称');
    if (name == null || name.isEmpty) return;
    try {
      await _sftp!.mkdir(_join(_cwd, name));
      await _list(_cwd);
    } catch (e) {
      _toast('新建失败：$e');
    }
  }

  Future<void> _rename(SftpName item) async {
    final name = await _promptText('重命名', '新名称', initial: item.filename);
    if (name == null || name.isEmpty || name == item.filename) return;
    try {
      await _sftp!.rename(_join(_cwd, item.filename), _join(_cwd, name));
      await _list(_cwd);
    } catch (e) {
      _toast('重命名失败：$e');
    }
  }

  Future<void> _delete(SftpName item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确定删除「${item.filename}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final path = _join(_cwd, item.filename);
      if (item.attr.isDirectory) {
        await _sftp!.rmdir(path);
      } else {
        await _sftp!.remove(path);
      }
      await _list(_cwd);
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  Future<String?> _promptText(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtSize(int? size) {
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtTime(int? epochSec) {
    if (epochSec == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.name),
        actions: [
          IconButton(
            tooltip: '上传文件',
            icon: const Icon(Icons.upload_outlined),
            onPressed: _sftp == null ? null : _upload,
          ),
          IconButton(
            tooltip: '新建文件夹',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _sftp == null ? null : _mkdir,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _sftp == null ? null : () => _list(_cwd),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: '上一级',
                onPressed: _cwd == '/' ? null : _goUp,
              ),
              title: Text(
                _cwd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _connect,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(child: Text('空目录'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final isDir = item.attr.isDirectory;
                              return ListTile(
                                leading: Icon(
                                  isDir
                                      ? Icons.folder_outlined
                                      : Icons.description_outlined,
                                ),
                                title: Text(item.filename),
                                subtitle: Text(
                                  isDir
                                      ? _fmtTime(item.attr.modifyTime)
                                      : '${_fmtSize(item.attr.size)}  ${_fmtTime(item.attr.modifyTime)}',
                                ),
                                onTap: isDir
                                    ? () => _list(_join(_cwd, item.filename))
                                    : null,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'download':
                                        _download(item);
                                        break;
                                      case 'rename':
                                        _rename(item);
                                        break;
                                      case 'delete':
                                        _delete(item);
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (!isDir)
                                      const PopupMenuItem(
                                        value: 'download',
                                        child: Text('下载'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text('重命名'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
