import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../models/connection_profile.dart';
import '../services/ssh_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.profile});

  final ConnectionProfile profile;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;
  String _title = '';

  @override
  void initState() {
    super.initState();
    _title = widget.profile.name;
    _connect();
  }

  Future<void> _connect() async {
    _terminal.write(
      '正在连接 ${widget.profile.username}@${widget.profile.host}:${widget.profile.port} ...\r\n',
    );
    try {
      final client = await SshService.connect(widget.profile);
      _client = client;
      _terminal.write('已连接\r\n');

      final session = await client.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );
      _session = session;

      _terminal.onOutput = (data) {
        session.write(utf8.encode(data));
      };
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        session.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };
      _terminal.onTitleChange = (title) {
        if (mounted && title.isNotEmpty) setState(() => _title = title);
      };

      session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);
      session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);

      if (mounted) setState(() => _connected = true);

      session.done.then((_) {
        _terminal.write('\r\n[连接已关闭]\r\n');
        if (mounted) setState(() => _connected = false);
      });
    } catch (e) {
      _terminal.write('\r\n连接失败：$e\r\n');
    }
  }

  @override
  void dispose() {
    _session?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: '断开',
            icon: const Icon(Icons.power_settings_new),
            onPressed: _connected
                ? () {
                    _session?.close();
                    _client?.close();
                    setState(() => _connected = false);
                  }
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: TerminalView(
          _terminal,
          autofocus: true,
          backgroundOpacity: 1,
        ),
      ),
    );
  }
}
