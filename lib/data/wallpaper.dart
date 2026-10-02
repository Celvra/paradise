import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Wallpapers live next to the stickers, under the app's own documents directory,
// so a picture the user picked keeps working after the gallery entry it came
// from is deleted or the permission is revoked.

const _dir = 'wallpapers';

Future<Directory> _wallpaperDir() async {
  final base = await getApplicationDocumentsDirectory();
  final d = Directory('${base.path}/$_dir');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// True when [path] is one of ours, so only files this app created are ever
/// deleted. A path the user somehow set by hand is left alone.
bool _isOurs(String path) => path.contains('/$_dir/');

String? _fileOf(String path) => path.isEmpty || !_isOurs(path) ? null : path;

/// Asks the gallery for a picture and copies it into the app's own storage.
/// Returns null when the user backs out.
Future<String?> pickWallpaper() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
  if (x == null) return null;
  final dir = await _wallpaperDir();
  final f = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${x.path.split('/').last}');
  try {
    await File(x.path).copy(f.path);
    return f.path;
  } catch (_) {
    // a copy that fails leaves the original path usable for this run at least
    return x.path;
  }
}

/// Deletes a wallpaper this app wrote, when nothing points at it any more.
/// Called with the path being replaced, after the caller has already stored the
/// new one, so the file being dropped is known to be unreferenced.
Future<void> dropWallpaperFile(String? old) async {
  final f = old == null ? null : _fileOf(old);
  if (f == null) return;
  try {
    final file = File(f);
    if (file.existsSync()) await file.delete();
  } catch (_) {
    // a leftover file is harmless, failing here is not worth surfacing
  }
}

/// Colours worth offering as an accent, pulled out of the picture itself.
///
/// The image is decoded at 64px wide, which is plenty to find the dominant
/// colours and cheap enough to run while the settings sheet is opening.
///
/// Pixels are bucketed by hue after dropping the near greys and the near
/// black and white: those make poor accents because an accent has to read
/// against both the page and the bubble. Buckets are then ranked by how much
/// saturated pixel they hold, and only buckets far enough apart in hue make the
/// cut, so the row of swatches does not offer six shades of the same blue.
Future<List<Color>> wallpaperSwatches(String path, {int count = 6}) async {
  ui.Image? image;
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];

    const buckets = 24;
    final weight = List<double>.filled(buckets, 0);
    final rSum = List<double>.filled(buckets, 0);
    final gSum = List<double>.filled(buckets, 0);
    final bSum = List<double>.filled(buckets, 0);

    final px = data.buffer.asUint8List();
    for (var i = 0; i + 3 < px.length; i += 4) {
      if (px[i + 3] < 200) continue;
      final c = Color.fromARGB(255, px[i], px[i + 1], px[i + 2]);
      final hsl = HSLColor.fromColor(c);
      if (hsl.saturation < 0.18) continue;
      if (hsl.lightness < 0.12 || hsl.lightness > 0.92) continue;
      final b = (hsl.hue / 360 * buckets).floor() % buckets;
      // saturated pixels define a colour better than washed out ones
      final w = hsl.saturation;
      weight[b] += w;
      rSum[b] += (c.r * 255) * w;
      gSum[b] += (c.g * 255) * w;
      bSum[b] += (c.b * 255) * w;
    }

    final ranked = <int>[for (var i = 0; i < buckets; i++) i]
      ..sort((a, b) => weight[b].compareTo(weight[a]));

    final out = <Color>[];
    for (final b in ranked) {
      if (weight[b] <= 0) break;
      final c = Color.fromARGB(255, (rSum[b] / weight[b]).round(), (gSum[b] / weight[b]).round(), (bSum[b] / weight[b]).round());
      final h = HSLColor.fromColor(c).hue;
      final tooClose = out.any((o) {
        final d = (HSLColor.fromColor(o).hue - h).abs();
        return math.min(d, 360 - d) < 24;
      });
      if (tooClose) continue;
      out.add(c);
      if (out.length >= count) break;
    }

    // a picture of nothing but grey has no accent to offer, say so rather than
    // hand back a grey that reads as a bug
    return out;
  } catch (_) {
    return const [];
  } finally {
    image?.dispose();
  }
}
