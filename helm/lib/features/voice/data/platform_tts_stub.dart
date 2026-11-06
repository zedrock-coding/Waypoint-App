// lib/features/voice/data/platform_tts_stub.dart

class PlatformTtsHelper {
  static bool get isWindows => false;

  static Future<bool> speakWindows(String text) async {
    return false;
  }

  static Future<void> stopWindows() async {}
}

