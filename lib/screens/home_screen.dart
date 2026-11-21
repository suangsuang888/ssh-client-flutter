import 'package:flutter/material.dart';

import '../models/connection_profile.dart';
import '../services/profile_store.dart';
import 'backup_screen.dart';
import 'file_browser_screen.dart';
import 'profile_edit_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = ProfileStore();
  List<ConnectionProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await _store.loadProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = list;
      _loading = false;
    });
  }

  Future<void> _persist() => _store.saveProfiles(_profiles);

  Future<void> _addOrEdit([ConnectionProfile? existing]) async {
    final result = await Navigator.of(context).push<ConnectionProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: existing),
      ),
    );
    if (result == null) return;
    setState(() {
      final idx = _profiles.indexWhere((p) => p.id == result.id);
      if (idx >= 0) {
        _profiles[idx] = result;
      } else {
        _profiles.add(result);
      }
    });
    await _persist();
  }

  Future<void> _delete(ConnectionProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除连接'),
        content: Text('确定删除「${p.name}」吗？'),
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
    setState(() => _profiles.removeWhere((e) => e.id == p.id));
    await _persist();
  }

  void _openTerminal(ConnectionProfile p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TerminalScreen(profile: p)),
    );
  }

  void _openFiles(ConnectionProfile p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileBrowserScreen(profile: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH 连接'),
        actions: [
          IconButton(
            tooltip: 'WebDAV 备份 / 恢复',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BackupScreen(
                    profiles: _profiles,
                    onRestored: (restored) async {
                      setState(() => _profiles = restored);
                      await _persist();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(
                  child: Text('还没有连接，点右下角 + 添加一个'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _profiles[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: Text(p.name),
                        subtitle: Text(p.subtitle),
                        onTap: () => _openTerminal(p),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'terminal':
                                _openTerminal(p);
                                break;
                              case 'files':
                                _openFiles(p);
                                break;
                              case 'edit':
                                _addOrEdit(p);
                                break;
                              case 'delete':
                                _delete(p);
                                break;
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'terminal',
                              child: Text('打开终端'),
                            ),
                            PopupMenuItem(
                              value: 'files',
                              child: Text('文件浏览'),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
