import 'package:flutter/material.dart';
import 'package:flutter_file_drop/flutter_file_drop.dart';

void main() => runApp(const DropExampleApp());

class DropExampleApp extends StatelessWidget {
  const DropExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'File drop example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF315C75)),
    home: const DropExamplePage(),
  );
}

class DropExamplePage extends StatefulWidget {
  const DropExamplePage({super.key});

  @override
  State<DropExamplePage> createState() => _DropExamplePageState();
}

class _DropExamplePageState extends State<DropExamplePage> {
  bool _hovering = false;
  DropPreview? _preview;
  Offset? _lastDropPosition;
  List<String> _messages = const <String>[];

  void _setHover(DropPreview preview) {
    setState(() {
      _hovering = true;
      _preview = preview;
    });
  }

  void _leave() {
    setState(() {
      _hovering = false;
      _preview = null;
    });
  }

  Future<void> _drop(DropResult result) async {
    final messages = <String>[];
    for (final entry in result.items) {
      if (!entry.accepted) {
        messages.add('Rejected ${_label(entry.item)}: ${entry.reasons}');
        continue;
      }
      final item = entry.item;
      if (item is DropFile) {
        var bytesRead = 0;
        await for (final chunk in item.openRead()) {
          bytesRead += chunk.length;
        }
        messages.add('Read ${item.name ?? 'unnamed file'}: $bytesRead bytes');
      } else if (item is DropString) {
        messages.add('${item.mimeType ?? 'text'}: ${_short(item.value)}');
      }
    }
    if (!mounted) return;
    setState(() {
      _hovering = false;
      _preview = null;
      _lastDropPosition = result.localPosition;
      _messages = messages;
    });
  }

  String _label(DropItem item) => switch (item) {
    DropFile(:final name) => name ?? 'file',
    DropString(:final mimeType) => mimeType ?? 'text',
  };

  String _short(String value) =>
      value.length <= 120 ? value : '${value.substring(0, 120)}…';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('flutter_file_drop')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const Text(
          'Drop files or supported text below. This package supplies behavior; '
          'the app supplies this surface.',
        ),
        const SizedBox(height: 16),
        DropTarget(
          constraints: DropConstraints(
            maxFiles: 4,
            maxFileSizeBytes: 100 * 1024 * 1024,
          ),
          onEnter: _setHover,
          onMove: _setHover,
          onLeave: _leave,
          onDrop: _drop,
          child: AnimatedContainer(
            key: const ValueKey<String>('drop-surface'),
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _hovering
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainer,
              border: Border.all(
                color: _hovering
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: _hovering ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _hovering ? 'Drag over target' : 'Drop target',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _preview == null
                      ? 'Files and text/plain, text/html, text/uri-list'
                      : '${_preview!.items.length} item(s) · '
                            'local ${_preview!.localPosition}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_lastDropPosition != null)
          Text('Last drop position: $_lastDropPosition'),
        for (final message in _messages)
          ListTile(
            dense: true,
            leading: const Icon(Icons.attach_file),
            title: Text(message),
          ),
      ],
    ),
  );
}
