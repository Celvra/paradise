import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The accent is read out of a picture, so it cannot outlive that picture.
/// These cover the store side of that: what happens to the colour when the
/// wallpaper behind it goes away or is swapped.
void main() {
  Future<Store> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return Store.load();
  }

  test('clearing the wallpaper clears the colour taken from it', () async {
    final s = await fresh();
    s.setWallpaper('/docs/wallpapers/1_photo.jpg');
    s.setWallpaperColor(0xFFE91E63);
    expect(s.wallpaperColor, 0xFFE91E63);

    s.setWallpaper('');
    expect(s.wallpaperColor, isNull);
    // and the palette went with it rather than staying tinted
    expect(themeCtl.accent, isNull);
  });

  test('picking a different photo clears the colour from the old one', () async {
    final s = await fresh();
    s.setWallpaper('/docs/wallpapers/1_old.jpg');
    s.setWallpaperColor(0xFF3F51B5);

    s.setWallpaper('/docs/wallpapers/2_new.jpg');
    expect(s.wallpaperColor, isNull);
  });

  test('re-picking the same photo keeps the colour', () async {
    // the guard is on the path changing, not on it being set at all, otherwise
    // opening the sheet and confirming the same picture would drop the accent
    final s = await fresh();
    s.setWallpaper('/docs/wallpapers/1_photo.jpg');
    s.setWallpaperColor(0xFFE91E63);

    s.setWallpaper('/docs/wallpapers/1_photo.jpg');
    expect(s.wallpaperColor, 0xFFE91E63);
  });

  test('a per chat override leaves the global colour alone', () async {
    // one conversation changing its wallpaper says nothing about the picture the
    // accent was lifted from
    final s = await fresh();
    s.setWallpaper('/docs/wallpapers/1_global.jpg');
    s.setWallpaperColor(0xFF009688);

    final chat = Chat(id: 'c1', persona: Persona(name: 'p', prompt: 'x', color: 0xFF229AF0));
    s.setChatWallpaper(chat, '/docs/wallpapers/2_chat.jpg');
    expect(s.wallpaperColor, 0xFF009688);

    s.setChatWallpaper(chat, null);
    expect(s.wallpaperColor, 0xFF009688);
  });

  test('the gradient level survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.wallpaperBubbleGrad, BubbleGrad.medium.index, reason: 'the shipped default');

    s.setWallpaperBubbleGrad(BubbleGrad.strong.index);
    final again = await Store.load();
    expect(again.wallpaperBubbleGrad, BubbleGrad.strong.index);
  });

  test('an out of range gradient level is clamped, not trusted', () async {
    // a value written by a build with more levels must not index off the end
    SharedPreferences.setMockInitialValues({'wallpaperBubbleGrad': 99});
    final s = await Store.load();
    expect(s.wallpaperBubbleGrad, BubbleGrad.values.length - 1);

    s.setWallpaperBubbleGrad(-5);
    expect(s.wallpaperBubbleGrad, 0);
  });

  test('picking the level reaches the palette', () async {
    final s = await fresh();
    s.setWallpaperColor(0xFFE91E63);
    s.setWallpaperBubbleGrad(BubbleGrad.strong.index);
    expect(themeCtl.grad, BubbleGrad.strong);
  });
}