import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/media_probe.dart';
import 'package:paradise/data/ai/tokenizer.dart';

/// The app prices a picture by its pixels because the provider bills it that
/// way, and it reads those pixels out of the header rather than decoding the
/// file. These are the shapes a phone camera and a gallery picker actually
/// hand over, cut down to the bytes the probe is allowed to look at.
void main() {
  test('a png states its size in the IHDR chunk', () {
    // the 1x1 red dot, the same fixture the attach tests send
    final dot = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    expect(imagePixelSize(dot), (width: 1, height: 1));
  });

  test('a gif states its size in the screen descriptor', () {
    final bytes = Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // 'GIF89a'
      0x40, 0x02, // width 576
      0x30, 0x01, // height 304
      0x00, 0x00, 0x00,
    ]);
    expect(imagePixelSize(bytes), (width: 576, height: 304));
  });

  test('a webp states its size in whichever chunk it carries', () {
    final extended = Uint8List(30);
    extended.setRange(0, 4, ascii.encode('RIFF'));
    extended.setRange(8, 12, ascii.encode('WEBP'));
    extended.setRange(12, 16, ascii.encode('VP8X'));
    // canvas size minus one, packed as 24 bit little endian
    extended[24] = 0xff;
    extended[27] = 0x2b;
    extended[28] = 0x01;
    expect(imagePixelSize(extended), (width: 256, height: 300));

    final lossy = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x20, //
      0, 0, 0, 0, 0, 0, 0, // frame tag
      0x9d, 0x01, 0x2a, // sync code
      0x0a, 0x02, 0xc0, 0x03, // width 522, height 960, two bytes each
    ]);
    expect(imagePixelSize(lossy), (width: 522, height: 960));
  });

  test('a jpeg is found behind the segment a camera puts in front of it', () {
    final bytes = Uint8List.fromList([
      0xff, 0xd8, // soi
      0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, // an APP0 exif block
      0xff, 0xc0, 0x00, 0x11, 0x08, 0x03, 0x00, 0x04, 0x00, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, // start of frame
      0xff, 0xd9, // eoi
    ]);
    expect(imagePixelSize(bytes), (width: 1024, height: 768));
  });

  test('a truncated or foreign file reads as unknown rather than as zero', () {
    expect(imagePixelSize(Uint8List(0)), isNull);
    expect(imagePixelSize(Uint8List.fromList(ascii.encode('not a picture at all, honestly'))), isNull);
    // a header that stops half way through is not a size of zero
    expect(imagePixelSize(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13])), isNull);
    expect(imagePixelSize(Uint8List.fromList([0xff, 0xd8, 0xff, 0xda, 0x00, 0x02, 0, 0, 0, 0, 0, 0])), isNull);
  });

  test('a known resolution is priced by tiles and an unknown one is not free', () {
    // 1568 on the long edge is the ceiling providers rescale to, four by four
    // tiles; a sticker is one tile
    expect(imageTokens(width: 1568, height: 1568), greaterThan(imageTokens(width: 64, height: 64)));
    expect(imageTokens(), greaterThan(imageTokens(width: 8, height: 8)));
    expect(imageTokens(width: 0, height: 0), imageTokens(), reason: 'a zero sized header is an unreadable one');
  });

  test('a clip is priced by the frames it will be sampled at', () {
    expect(videoTokens(seconds: 30, base64Chars: 1000), greaterThan(videoTokens(seconds: 2, base64Chars: 1000)));
    expect(videoTokens(base64Chars: 4 * 1024 * 1024), greaterThan(0), reason: 'an untimed clip still costs something');
  });
}