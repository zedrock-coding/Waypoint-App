// lib/features/voice/data/platform_tts_io.dart

import 'dart:async';
import 'dart:io';

class PlatformTtsHelper {
  static Process? _activeProcess;

  static bool get isWindows => Platform.isWindows;

  static Future<bool> speakWindows(String text) async {
    if (!isWindows) return false;
    final clean = text.trim();
    if (clean.isEmpty) return true;

    await stopWindows();

    try {
      final escaped = clean.replaceAll('"', '""').replaceAll("'", "''");
      _activeProcess = await Process.start('mshta', [
        'vbscript:Execute("CreateObject(""SAPI.SpVoice"").Speak(""$escaped"")(window.close)")'
      ]);
      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;
      return exitCode == 0;
    } catch (_) {
      try {
        final escaped = clean.replaceAll("'", "''");
        _activeProcess = await Process.start('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "[System.Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null; \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$s.Speak('$escaped')",
        ]);
        final exitCode = await _activeProcess!.exitCode;
        _activeProcess = null;
        return exitCode == 0;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<void> stopWindows() async {
    try {
      _activeProcess?.kill();
      _activeProcess = null;
    } catch (_) {}
  }
}

