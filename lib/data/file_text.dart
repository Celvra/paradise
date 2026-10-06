import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Text extraction for file attachments on their way into the model context.
// Kept out of the store so the sampling rules stay unit-testable without
// booting a Store.

/// Extensions that are binary by construction and never worth decoding. An
/// unknown extension is not on this list: it goes through the decode probe
/// instead, so a `.srt` or a vendor log format still reaches the model.
const binaryFileExts = {
  // archives & packages
  'zip', 'apk', 'aab', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'zst', 'jar', 'war',
  // documents with non-plain encodings
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf', 'pages', 'numbers', 'key', 'epub', 'mobi', 'azw3', 'chm', 'ps',
  // design / fonts
  'psd', 'ai', 'eps', 'fig', 'sketch', 'xd', 'ttf', 'otf', 'woff', 'woff2', 'eot',
  // compiled / executable
  'class', 'dex', 'so', 'dll', 'exe', 'msi', 'dmg', 'iso', 'bin', 'dat', 'db', 'sqlite', 'sqlite3', 'realm', 'wallet',
  // media (routed to the photo/video pipeline instead of text injection)
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif', 'avif', 'tiff', 'tif', 'ico', 'raw', 'cr2', 'nef',
  'mp3', 'flac', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'opus', 'wma', 'aiff',
  'mp4', 'mkv', 'webm', 'mov', 'avi', '3gp', '3g2', 'ts', 'm4v', 'wmv', 'mpg', 'mpeg', 'flv', 'rmvb',
};

bool isBinaryExt(String path) => binaryFileExts.contains(path.split('.').last.toLowerCase());

/// Hard ceiling on bytes even considered for sampling, so a 4 GB log dump is
/// rejected by the stat before a single byte is read.
const sampleMaxBytes = 2 * 1024 * 1024;

class FileSample {
  const FileSample(this.text, this.usedChars, this.omittedChars);
  final String text;

  /// characters charged against the per-request budget, so the caller can stop
  /// injecting once the context allowance is spent
  final int usedChars;

  /// characters of the file that did not make it into [text], zero on a full
  /// read; surfaced in the omission marker so the model knows it is seeing an
  /// excerpt
  final int omittedChars;
}

bool _looksBinary(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  var control = 0;
  final probe = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
  for (final b in probe) {
    if (b < 0x09 || (b > 0x0D && b < 0x20)) control++;
  }
  // utf-8 multi-byte sequences never land in the control range, so a 2%
  // control share means a genuinely binary payload
  return control / probe.length > 0.02;
}

String _decode(Uint8List bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } catch (_) {
    // latin-1 maps every byte to a char so the excerpt stays decodable; the
    // printable-ratio probe already ran on the raw bytes
    return latin1.decode(bytes, allowInvalid: true);
  }
}

/// Reads up to [maxChars] of text from [path], or null when the file is
/// binary, unreadable, or empty. Over-budget files yield a head plus a tail
/// around an omission marker so both the opening and the most recent content
/// survive.
FileSample? sampleTextFile(String path, int maxChars) {
  if (isBinaryExt(path)) return null;
  RandomAccessFile? raf;
  try {
    raf = File(path).openSync();
    final len = raf.lengthSync();
    if (len == 0 || len > sampleMaxBytes) return null;
    if (len <= maxChars) {
      final raw = raf.readSync(len);
      if (_looksBinary(raw)) return null;
      final text = _decode(raw);
      if (text.trim().isEmpty) return null;
      return FileSample(text, text.length, 0);
    }
    // 70% head, the rest tail; a mid-file cut can split a utf-8 sequence, so
    // each side decodes leniently on its own
    final headBytes = (maxChars * 0.7).floor();
    final tailBytes = maxChars - headBytes;
    final head = raf.readSync(headBytes);
    raf.setPositionSync(len - tailBytes);
    final tail = raf.readSync(tailBytes);
    final probe = Uint8List(headBytes + tailBytes)
      ..setRange(0, headBytes, head)
      ..setRange(headBytes, headBytes + tailBytes, tail);
    if (_looksBinary(probe)) return null;
    final headText = utf8.decode(head, allowMalformed: true);
    final tailText = utf8.decode(tail, allowMalformed: true);
    if (headText.trim().isEmpty && tailText.trim().isEmpty) return null;
    final body = '$headText\n[... ${len - maxChars} bytes omitted ...]\n$tailText';
    return FileSample(body, body.length, len - maxChars);
  } catch (_) {
    return null;
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {}
  }
}
