// lib/features/voice/data/wav_audio_container_util.dart

import 'dart:io';
import 'dart:typed_data';

/// Formats and encapsulates raw linear PCM audio buffers into standardized
/// 44-byte RIFF/WAV containers compatible with standard system audio decoders.
class WavAudioContainerUtil {
  /// Encapsulates raw linear PCM bytes in a standard 44-byte RIFF/WAV header.
  /// Defaults to 16-bit mono PCM at 16000 Hz.
  static Uint8List createWavContainer(
    Uint8List pcmSamples, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final int dataSize = pcmSamples.length;
    final int totalSize = 36 + dataSize;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);

    final ByteData header = ByteData(44);

    // 0-3: "RIFF"
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'

    // 4-7: ChunkSize (36 + SubChunk2Size)
    header.setUint32(4, totalSize, Endian.little);

    // 8-11: "WAVE"
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // 12-15: "fmt "
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '

    // 16-19: Subchunk1Size (16 for linear PCM)
    header.setUint32(16, 16, Endian.little);

    // 20-21: AudioFormat (1 = PCM)
    header.setUint16(20, 1, Endian.little);

    // 22-23: NumChannels
    header.setUint16(22, numChannels, Endian.little);

    // 24-27: SampleRate
    header.setUint32(24, sampleRate, Endian.little);

    // 28-31: ByteRate
    header.setUint32(28, byteRate, Endian.little);

    // 32-33: BlockAlign
    header.setUint16(32, blockAlign, Endian.little);

    // 34-35: BitsPerSample
    header.setUint16(34, bitsPerSample, Endian.little);

    // 36-39: "data"
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'

    // 40-43: Subchunk2Size (data length in bytes)
    header.setUint32(40, dataSize, Endian.little);

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcmSamples);

    return wavBytes;
  }

  /// Writes raw sample bytes wrapped in a 44-byte WAV header directly to physical disk.
  static Future<File> writeWavFile(
    String filePath,
    Uint8List pcmSamples, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) async {
    final Uint8List wavBytes = createWavContainer(
      pcmSamples,
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitsPerSample: bitsPerSample,
    );
    final File file = File(filePath);
    await file.parent.create(recursive: true);
    return await file.writeAsBytes(wavBytes, flush: true);
  }

  /// Validates whether the given bytes conform to a standard 44-byte RIFF/WAV header.
  static bool isValidWavHeader(Uint8List bytes) {
    if (bytes.length < 44) return false;

    // Check "RIFF"
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
      return false;
    }

    // Check "WAVE"
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
      return false;
    }

    // Check "fmt "
    if (bytes[12] != 0x66 || bytes[13] != 0x6D || bytes[14] != 0x74 || bytes[15] != 0x20) {
      return false;
    }

    // Check "data"
    if (bytes[36] != 0x64 || bytes[37] != 0x61 || bytes[38] != 0x74 || bytes[39] != 0x61) {
      return false;
    }

    // Validate declared lengths
    final ByteData view = ByteData.sublistView(bytes);
    final int chunkSize = view.getUint32(4, Endian.little);
    final int subchunk2Size = view.getUint32(40, Endian.little);

    if (chunkSize != 36 + subchunk2Size) return false;
    if (bytes.length < 44 + subchunk2Size) return false;

    return true;
  }
}

