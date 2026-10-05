import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart' show MsgKind;
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/canvas_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A canvas message is the model drawing or typesetting straight onto the page:
// no bubble behind it, full column width, the long press belongs to the
// rendered thing itself. Math renders natively through RaTeX (Rust FFI, no
// webview), so the tester exercises the real widget — a parse failure calls
// onFailed and the card collapses to the quiet notice.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'chats': '[]'});
  L10n.sync(AppLocalizationsEn());

  Future<Store> store() async => Store.load();

  Widget wrap(Store st, Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StoreScope(
          store: st,
          child: ThemeScope(
            controller: themeCtl,
            child: MediaQuery(data: const MediaQueryData(), child: child),
          ),
        ),
      );

  testWidgets('a math card holds together in the tester', (t) async {
    // The FFI engine cannot load inside the plain tester (no bundled host
    // library), so a full render can only be exercised on a device. Here it
    // is enough that the card neither crashes nor paints the raw source: the
    // engine call times out, the card collapses to the notice, and the raw
    // formula is never shown.
    final st = await store();
    await t.pumpWidget(wrap(st, CanvasCard(source: r'\int_0^\infty e^{-x}\,dx = 1', latex: true)));
    await t.pump(const Duration(milliseconds: 50));
    // advance past the engine timeout so no timer is left pending
    await t.pump(const Duration(seconds: 21));
    expect(t.takeException(), isNull);
    expect(find.textContaining(r'\int_0^\infty', findRichText: true), findsNothing);
  });

  testWidgets('a html card does not crash when no webview is available', (t) async {
    // The tester has no webview platform implementation, so the card must
    // fail quietly (notice) rather than throw or dump the raw markup.
    final st = await store();
    await t.pumpWidget(wrap(st, CanvasCard(source: '<p>hello card</p>', latex: false)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.textContaining('<p>hello card</p>', findRichText: true), findsNothing);
  });

  test("delimiters a model wraps around formulas are stripped", () {
    final doc = _DelimProbe();
    expect(doc.strip(r'$$E=mc^2$$'), 'E=mc^2');
    expect(doc.strip(r'\[E=mc^2\]'), 'E=mc^2');
    expect(doc.strip(r'$E=mc^2$'), 'E=mc^2');
    expect(doc.strip('E=mc^2'), 'E=mc^2');
  });

  test('TikZ drawing code is told apart from real math', () {
    // The model reaches for TikZ whenever it wants a picture; send_latex must
    // recognise it and redirect to send_cetz instead of queueing a card the
    // math engine is guaranteed to reject.
    expect(looksLikeTikz(r'\begin{tikzpicture}\draw (0,0)--(1,1);\end{tikzpicture}'), isTrue);
    expect(looksLikeTikz(r'\draw[red,thick] (0,0) -- (1,1);'), isTrue);
    expect(looksLikeTikz(r'\node at (0,0) {hi};'), isTrue);
    expect(looksLikeTikz(r'\fill[blue] (0,0) circle (1);'), isTrue);
    expect(looksLikeTikz(r'\foreach \i in {1,...,3} { \draw (0,0)--(\i,1); }'), isTrue);
    expect(looksLikeTikz(r'\begin{axis}\addplot {x^2};\end{axis}'), isTrue);

    // ordinary formulas must never be misread as drawings
    expect(looksLikeTikz(r'E = mc^2'), isFalse);
    expect(looksLikeTikz(r'\int_0^\infty e^{-x}\,dx = \frac{\sqrt{\pi}}{2}'), isFalse);
    expect(looksLikeTikz(r'\begin{aligned} a &= b \\ c &= d \end{aligned}'), isFalse);
    expect(looksLikeTikz(r'\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}'), isFalse);
    expect(looksLikeTikz(r'\colorbox{yellow}{$x^2$}'), isFalse);
  });

  test('the shipped cetz packages are self-contained and path-importable', () {
    // The card imports cetz from the bundle by relative path, so the bundle
    // must carry the entry points and every package-internal import must
    // resolve without @preview (which would need the network).
    final raw = File('assets/typst/packages.tgz').readAsBytesSync();
    final gz = GZipDecoder().decodeBytes(raw);
    final tar = TarDecoder().decodeBytes(gz);
    final files = <String, Uint8List>{};
    for (final f in tar.files) {
      files[f.name] = f.content;
    }
    expect(files.keys, contains('packages/cetz/0.5.2/src/lib.typ'));
    expect(files.keys, contains('packages/cetz-plot/0.1.4/src/lib.typ'));
    expect(files.keys, contains('packages/oxifmt/1.0.0/lib.typ'));
    // cetz 0.5 draws with a wasm plugin; without it every canvas dies at
    // "file not found (searched at cetz-core/cetz_core.wasm)"
    expect(files.keys, contains('packages/cetz/0.5.2/cetz-core/cetz_core.wasm'));

    // The bundle is loaded from plain virtual paths, not as a @preview package,
    // so Typst resolves a leading `/` against the virtual root, not the package
    // root. Upstream cetz uses `/src/...` and `/cetz-core/...` freely; those
    // must all have been rewritten to relative paths or the compiler cannot
    // find them.
    final importRe = RegExp(r'(?:import|plugin)\s*\(\s*"([^"]+)"|import\s+"([^"]+)"');
    for (final e in files.entries) {
      if (!e.key.endsWith('.typ')) continue;
      final body = String.fromCharCodes(e.value);
      expect(body.contains('@preview'), isFalse, reason: '${e.key} still imports @preview');
      expect(body.contains('"/'), isFalse, reason: '${e.key} still has a root-absolute path');
      for (final m in importRe.allMatches(body)) {
        final target = m.group(1) ?? m.group(2)!;
        final resolved = _resolveVirtual(e.key, target);
        expect(files.keys, contains(resolved), reason: '${e.key} imports missing $target');
      }
    }
  });

  test('a cetz snippet is wrapped with a local import and canvas', () {
    final page = wrapCetz('circle((0, 0), radius: 1)', dark: false);
    expect(page, contains('#import "packages/cetz/0.5.2/src/lib.typ" as cetz'));
    expect(page, contains('#cetz.canvas'));
    expect(page, contains('circle((0, 0), radius: 1)'));
    expect(page, contains('rgb("#1b1b1b")'));
  });

  test('a full cetz snippet keeps its own import and is not double wrapped', () {
    final src = '#cetz.canvas({\n  import cetz.draw: *\n  circle((0,0), radius: 1)\n})';
    final page = wrapCetz(src, dark: true);
    expect(page, contains('#cetz.canvas'));
    expect(page, isNot(contains('#cetz.canvas(length: 1cm, {\n  import cetz.draw: *\n  #cetz.canvas')));
    expect(page, contains('rgb("#e8eaed")'));
  });

  test('a model @preview import is rewritten to the bundled path', () {
    final page = wrapCetz('#import "@preview/cetz:0.5.2": *\n#cetz.canvas({})', dark: false);
    expect(page, isNot(contains('@preview')));
    expect(page, contains('packages/cetz/0.5.2/src/lib.typ'));
  });

  test('a render failure is recorded on the message and reaches the transcript', () async {
    final st = await Store.load();
    final c = st.createChat('A', 'p');
    final m = st.humanSay(c, 'see', kind: MsgKind.latex, data: {'source': r'E=mc^2'});
    expect(st.humanDescribe(m), isNot(contains('FAILED')));
    st.canvasRenderFailed(c, m, 'KaTeX parse error: Undefined control sequence');
    expect(m.data['renderError'], contains('Undefined control sequence'));
    final described = st.humanDescribe(m);
    expect(described, contains('FAILED'));
    expect(described, contains('Undefined control sequence'));
    // a repeat of the same failure does not spam the change log
    st.canvasRenderFailed(c, m, 'KaTeX parse error: Undefined control sequence');
  });
}

// exposes the private delimiter stripping through a subclass probe
class _DelimProbe extends MathDoc {
  _DelimProbe() : super(source: '', align: CardAlign.center, onFailed: (_) {});
  @override
  String strip(String s) => super.strip(s);
}

/// Joins a relative import against the directory of the file that wrote it,
/// the same way Typst resolves it, then normalizes `..` so the result is the
/// key it must have in the bundle.
String _resolveVirtual(String from, String target) {
  final parts = from.split('/')..removeLast();
  for (final seg in target.split('/')) {
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (seg != '.' && seg.isNotEmpty) {
      parts.add(seg);
    }
  }
  return parts.join('/');
}
