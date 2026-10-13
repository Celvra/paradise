import 'dart:typed_data';

/// Pixel size of an encoded picture, read from the header alone.
///
/// Vision models bill by pixels, so the app needs the resolution of what it
/// sends to keep its own context accounting honest. Decoding the picture to
/// find out would cost exactly the memory this avoids: every container format
/// a phone camera writes states its size in the first few dozen bytes.
///
/// Null means "not a format we read", never "zero pixels". The caller falls
/// back to a middling estimate for those rather than treating the picture as
/// free, which is what made a window full of photos look empty.
({int width, int height})? imagePixelSize(Uint8List b) {
  // short enough that no magic byte reads past the end; every format below
  // checks the length its own header needs
  if (b.length < 10) return null;
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) return _png(b);
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return _gif(b);
  if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46) return _webp(b);
  if (b[0] == 0xff && b[1] == 0xd8) return _jpeg(b);
  return null;
}

({int width, int height})? _pair(int w, int h) {
  // a corrupted header can carry anything, and a zero sized picture would
  // divide the tile count into nonsense
  if (w <= 0 || h <= 0 || w > 100000 || h > 100000) return null;
  return (width: w, height: h);
}

int _u16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];

int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);

int _u32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

({int width, int height})? _png(Uint8List b) {
  // signature(8) length(4) 'IHDR'(4) then the two big endian dimensions
  if (b.length < 24) return null;
  return _pair(_u32(b, 16), _u32(b, 20));
}

({int width, int height})? _gif(Uint8List b) {
  // 'GIF87a' / 'GIF89a' then the logical screen descriptor
  if (b.length < 10) return null;
  return _pair(_u16le(b, 6), _u16le(b, 8));
}

({int width, int height})? _webp(Uint8List b) {
  // 'RIFF' size(4) 'WEBP' then a chunk: 'VP8 ' lossy, 'VP8L' lossless,
  // 'VP8X' the extended header that also carries animations
  if (b.length < 30) return null;
  final kind = String.fromCharCodes(b.sublist(12, 16));
  switch (kind) {
    case 'VP8 ':
      // the frame tag, then the 9d 01 2a sync code, then two 14 bit sizes
      if (b.length < 30 || b[23] != 0x9d || b[24] != 0x01 || b[25] != 0x2a) return null;
      return _pair(_u16le(b, 26) & 0x3fff, _u16le(b, 28) & 0x3fff);
    case 'VP8L':
      // a 0x2f signature then a bit packed header: 14 bits width, 14 bits
      // height, both one less than the real size
      if (b.length < 25 || b[20] != 0x2f) return null;
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return _pair((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
    case 'VP8X':
      // canvas size minus one, packed as 24 bit little endian
      if (b.length < 30) return null;
      final w = b[24] | (b[25] << 8) | (b[26] << 16);
      final h = b[27] | (b[28] << 8) | (b[29] << 16);
      return _pair(w + 1, h + 1);
  }
  return null;
}

({int width, int height})? _jpeg(Uint8List b) {
  // walk the marker segments until a start of frame turns up: everything
  // before it (quantisation, huffman tables, the thumbnail) is skippable
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xff) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    // a run of 0xff is legal padding, and these markers carry no payload
    if (marker == 0xff || marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2;
      continue;
    }
    // the frame headers, minus the entropy tables and the arithmetic ones
    // that share the range
    final frame = marker >= 0xc0 && marker <= 0xcf && marker != 0xc4 && marker != 0xc8 && marker != 0xcc;
    if (frame) {
      // length(2) precision(1) height(2) width(2)
      return _pair(_u16(b, i + 7), _u16(b, i + 5));
    }
    // the scan starts the entropy coded pixels, no frame header before it
    if (marker == 0xda) return null;
    final length = _u16(b, i + 2);
    if (length < 2) return null;
    i += 2 + length;
  }
  return null;
}