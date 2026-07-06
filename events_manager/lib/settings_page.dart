import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'models/settings.dart';

class SettingPage extends StatefulWidget {
  final Isar isar;
  const SettingPage({super.key, required this.isar});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  Settings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.isar.settings.get(0);
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _updateFontSize(double value) async {
    if (_settings == null) return;
    setState(() {
      _settings!.fontSizeIndex = value.toInt();
    });
    await widget.isar.writeTxn(() async {
      await widget.isar.settings.put(_settings!);
    });
  }

  Future<void> _updateThemeMode(int mode) async {
    if (_settings == null) return;
    setState(() {
      _settings!.themeMode = mode;
    });
    await widget.isar.writeTxn(() async {
      await widget.isar.settings.put(_settings!);
    });
  }

  Future<void> _uploadTheme() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        String content;
        if (result.files.single.bytes != null) {
          content = utf8.decode(result.files.single.bytes!);
        } else {
          File file = File(result.files.single.path!);
          content = await file.readAsString();
        }

        // Basic validation
        final json = jsonDecode(content);
        if (json['seedColor'] != null) {
          setState(() {
            _settings!.customThemeJson = content;
            _settings!.themeMode = 2; // Switch to custom
          });
          await widget.isar.writeTxn(() async {
            await widget.isar.settings.put(_settings!);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Custom theme applied!')),
            );
          }
        } else {
          throw Exception('Missing seedColor');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid theme file: $e')),
        );
      }
    }
  }

  void _showSampleTheme() {
    const sample = '''
{
  "seedColor": "0xFFE91E63",
  "brightness": "dark",
  "backgroundColor": "0xFF1A1A1A",
  "comment": "Colors must be in 0xAARRGGBB format. brightness can be 'light' or 'dark'."
}
''';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sample Theme JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Copy this JSON to a .json file, modify it, and upload it back.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: const SelectableText(
                sample,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: sample));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sample copied to clipboard!')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final fontSizeLabels = ['Very Small', 'Small', 'Normal', 'Medium', 'Large'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Font Size: ${fontSizeLabels[_settings!.fontSizeIndex]}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _settings!.fontSizeIndex.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            label: fontSizeLabels[_settings!.fontSizeIndex],
            onChanged: _updateFontSize,
          ),
          const Divider(),
          const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<int>(
            title: const Text('Light'),
            value: 0,
            groupValue: _settings!.themeMode,
            onChanged: (val) => _updateThemeMode(val!),
          ),
          RadioListTile<int>(
            title: const Text('Dark'),
            value: 1,
            groupValue: _settings!.themeMode,
            onChanged: (val) => _updateThemeMode(val!),
          ),
          RadioListTile<int>(
            title: const Text('Custom Theme'),
            value: 2,
            groupValue: _settings!.themeMode,
            onChanged: (val) => _updateThemeMode(val!),
          ),
          if (_settings!.themeMode == 2) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _uploadTheme,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Custom Theme (JSON)'),
            ),
            if (_settings!.customThemeJson == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No custom theme uploaded yet.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _showSampleTheme,
            icon: const Icon(Icons.code),
            label: const Text('View Sample Theme Template'),
          ),
        ],
      ),
    );
  }
}
