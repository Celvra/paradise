import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/workspace/file_diff.dart';
import 'package:paradise/data/workspace/host_file_tools.dart';
import 'package:paradise/data/workspace/workspace_paths.dart';

// The filesystem engine. The read cap, the edit fallbacks and the traversal
// rules are the parts that will be wrong quietly rather than loudly.

void main() {
  late Directory tmp;
  late WorkspacePaths paths;
  late HostFileTools tools;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ws_files');
    for (final n in ['ws', 'chat', 'skills', 'tmp']) {
      await Directory('${tmp.path}/$n').create(recursive: true);
    }
    paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: '${tmp.path}/ws',
      chatHostRoot: '${tmp.path}/chat',
      skillsHostRoot: '${tmp.path}/skills',
      tmpHostRoot: '${tmp.path}/tmp',
    );
    tools = HostFileTools(paths);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> wsFile(String name, [String content = '']) async {
    final f = File('${tmp.path}/ws/$name');
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
    return f;
  }

  group('read_file', () {
    test('numbers the lines', () async {
      await wsFile('a.txt', 'one\ntwo\nthree');
      final r = await tools.readFile('/workspace/a.txt');
      expect(r.lines, ['     1|one', '     2|two', '     3|three']);
      expect(r.nextOffset, 0);
    });

    test('offset pages forward', () async {
      await wsFile('a.txt', 'l1\nl2\nl3\nl4\nl5');
      final r = await tools.readFile('/workspace/a.txt', offset: 3, limit: 2);
      expect(r.lines, ['     3|l3', '     4|l4']);
      expect(r.nextOffset, 5);
    });

    test('an offset past the end returns nothing rather than throwing', () async {
      await wsFile('a.txt', 'l1\nl2');
      expect((await tools.readFile('/workspace/a.txt', offset: 99)).lines, isEmpty);
    });

    test('the byte cap ends the read and reports where to continue', () async {
      final big = List.generate(6000, (i) => 'line $i ${'x' * 40}').join('\n');
      await wsFile('big.txt', big);
      final r = await tools.readFile('/workspace/big.txt');
      expect(r.lines.length, lessThan(6000));
      expect(r.nextOffset, greaterThan(0));
      // and the next page really does continue from there
      final next = await tools.readFile('/workspace/big.txt', offset: r.nextOffset);
      expect(next.lines.first, contains(r.nextOffset.toString().padLeft(6)));
    });

    test('a single enormous line is cut and marked', () async {
      await wsFile('min.js', 'y' * 200000);
      final r = await tools.readFile('/workspace/min.js');
      // no trailing newline, so this is the flush path rather than the loop
      expect(r.lines, hasLength(1));
      expect(r.lines.first, contains('line truncated'));
    });

    test('a nul byte means binary and the bytes come back as hex', () async {
      final f = File('${tmp.path}/ws/bin.dat');
      await f.writeAsBytes([1, 2, 0, 3, 4]);
      final r = await tools.readFile('/workspace/bin.dat');
      expect(r.binary, isTrue);
      expect(r.hexPreview, '01 02 00 03 04');
    });

    test('a multibyte line cut at the cap does not produce a broken rune', () async {
      // every line is one CJK char repeated, so the cap lands mid character
      final f = File('${tmp.path}/ws/cjk.txt');
      final unit = List.filled(900, 0x4e2d).map((b) => String.fromCharCode(b)).join();
      final lines = List.generate(40, (i) => '$unit$i');
      await f.writeAsString(lines.join('\n'));
      final r = await tools.readFile('/workspace/cjk.txt');
      // a replacement char would show up as U+FFFD, which is not in the source
      expect(r.lines.join('\n').contains('�'), isFalse);
    });

    test('crlf lines do not leak a carriage return', () async {
      await wsFile('crlf.txt', 'one\r\ntwo\r\n');
      final r = await tools.readFile('/workspace/crlf.txt');
      expect(r.lines, ['     1|one', '     2|two']);
    });

    test('an image comes back as bytes', () async {
      final f = File('${tmp.path}/ws/p.png');
      await f.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      final r = await tools.readFile('/workspace/p.png');
      expect(r.isImage, isTrue);
      expect(r.imageMime, 'image/png');
      expect(r.imageBytes, hasLength(8));
    });

    test('a missing file says so', () async {
      expect(() => tools.readFile('/workspace/nope.txt'), throwsA(isA<HostFileException>()));
    });

    test('a directory says to use list_dir', () async {
      await Directory('${tmp.path}/ws/d').create();
      expect(
        () => tools.readFile('/workspace/d'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('list_dir'))),
      );
    });

    test('an escape attempt is a file error, not a path error', () async {
      expect(
        () => tools.readFile('/workspace/../etc/passwd'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('escapes'))),
      );
    });
  });

  group('write_file', () {
    test('creates a file and its parents', () async {
      final r = await tools.writeFile('/workspace/deep/a/b.txt', 'hello');
      expect(r.created, isTrue);
      expect(r.bytes, 5);
      expect(await File('${tmp.path}/ws/deep/a/b.txt').readAsString(), 'hello');
    });

    test('overwriting an existing file is not a create', () async {
      await wsFile('a.txt', 'old');
      final r = await tools.writeFile('/workspace/a.txt', 'new');
      expect(r.created, isFalse);
    });

    test('refuses the skills zone', () async {
      expect(
        () => tools.writeFile('/skills/k/SKILL.md', 'x'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('read only'))),
      );
    });

    test('refuses a traversal', () async {
      await expectLater(() => tools.writeFile('/workspace/../escape.txt', 'x'), throwsA(isA<HostFileException>()));
    });

    test('checkCancelled runs before anything is written', () async {
      var called = 0;
      final t = HostFileTools(paths, checkCancelled: () {
        called++;
        throw HostFileException('cancelled');
      });
      await expectLater(t.writeFile('/workspace/a.txt', 'x'), throwsA(isA<HostFileException>()));
      expect(called, greaterThan(0));
      // and the disk is untouched, which is the point of asking first
      expect(await File('${tmp.path}/ws/a.txt').exists(), isFalse);
    });
  });

  group('edit_file', () {
    test('replaces an exact match', () async {
      await wsFile('a.txt', 'alpha\nbeta\ngamma');
      final r = await tools.editFile('/workspace/a.txt', 'beta', 'BETA');
      expect(r.strategy, 'exact');
      expect(r.replacements, 1);
      expect(await File('${tmp.path}/ws/a.txt').readAsString(), 'alpha\nBETA\ngamma');
    });

    test('a unique match is required unless replace_all', () async {
      await wsFile('a.txt', 'x\nx\n');
      expect(
        () => tools.editFile('/workspace/a.txt', 'x', 'y'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('matches 2 places'))),
      );
      final all = await tools.editFile('/workspace/a.txt', 'x', 'y', replaceAll: true);
      expect(all.replacements, 2);
      expect(await File('${tmp.path}/ws/a.txt').readAsString(), 'y\ny\n');
    });

    test('falls back to a trimmed match when the surrounding lines drifted', () async {
      // the needle must not be a substring of the file, or the exact branch
      // wins and the fallback is never reached
      await wsFile('a.dart', 'void main() {\n  print(1);\n}\n');
      final r = await tools.editFile('/workspace/a.dart', '    print(1);\n', '    print(2);\n');
      expect(r.strategy, 'line-trimmed');
      expect(await File('${tmp.path}/ws/a.dart').readAsString(), 'void main() {\n    print(2);\n}\n');
    });

    test('falls back to an anchored match when the body drifted', () async {
      // the model remembered the signature and the closing brace but wrote a
      // different body, and a body of a different length besides
      await wsFile('a.dart', 'class A {\n  void one() {}\n  void two() {}\n}\nvoid after() {}\n');
      final r = await tools.editFile('/workspace/a.dart', 'class A {\n  void uno() {}\n}\n', 'class A {\n}\n');
      expect(r.strategy, 'block-anchor');
      expect(await File('${tmp.path}/ws/a.dart').readAsString(), 'class A {\n}\nvoid after() {}\n');
    });

    test('a miss says to read the file again', () async {
      await wsFile('a.txt', 'content');
      expect(
        () => tools.editFile('/workspace/a.txt', 'nothing like this', 'x'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('read_file'))),
      );
    });

    test('an empty old_string is refused', () async {
      await wsFile('a.txt', 'content');
      expect(() => tools.editFile('/workspace/a.txt', '', 'x'), throwsA(isA<HostFileException>()));
    });

    test('editing a file that is not there points at write_file', () async {
      expect(
        () => tools.editFile('/workspace/nope.txt', 'a', 'b'),
        throwsA(isA<HostFileException>().having((e) => e.message, 'message', contains('write_file'))),
      );
    });

    test('a crlf file keeps its endings', () async {
      await wsFile('a.txt', 'one\r\ntwo\r\n');
      await tools.editFile('/workspace/a.txt', 'two', 'TWO');
      expect(await File('${tmp.path}/ws/a.txt').readAsString(), 'one\r\nTWO\r\n');
    });

    test('the diff is produced and is not what the model gets back', () async {
      await wsFile('a.txt', 'one\ntwo\n');
      final r = await tools.editFile('/workspace/a.txt', 'one', 'ONE');
      expect(r.diff, contains('-one'));
      expect(r.diff, contains('+ONE'));
      expect(r.added, 1);
      expect(r.removed, 1);
    });
  });

  group('list_dir', () {
    test('directories come before files', () async {
      await wsFile('z.txt', 'z');
      await wsFile('a.txt', 'a');
      await Directory('${tmp.path}/ws/m').create();
      final r = await tools.listDir('/workspace');
      expect(r.entries.map((e) => e.name), ['m', 'a.txt', 'z.txt']);
    });

    test('depth walks deeper', () async {
      await wsFile('one/two/three.txt', 'x');
      expect((await tools.listDir('/workspace')).entries, hasLength(1));
      expect((await tools.listDir('/workspace', depth: 3)).entries.map((e) => e.name), contains('three.txt'));
    });

    test('hidden entries are skipped', () async {
      await wsFile('.secret', 'x');
      await wsFile('shown', 'x');
      expect((await tools.listDir('/workspace')).entries.map((e) => e.name), ['shown']);
    });

    test('the cap trips and says so', () async {
      for (var i = 0; i < HostFileTools.listCap + 20; i++) {
        await wsFile('f${i.toString().padLeft(4, '0')}.txt', 'x');
      }
      final r = await tools.listDir('/workspace');
      expect(r.entries, hasLength(HostFileTools.listCap));
      expect(r.truncated, isTrue);
    });

    test('a relative path uses the cwd', () async {
      await wsFile('sub/a.txt', 'x');
      final p = WorkspacePaths.sandboxed(
        workspaceHostRoot: '${tmp.path}/ws',
        chatHostRoot: '${tmp.path}/chat',
        skillsHostRoot: '${tmp.path}/skills',
        tmpHostRoot: '${tmp.path}/tmp',
        cwd: '/workspace/sub',
      );
      expect((await HostFileTools(p).listDir('.')).entries.map((e) => e.name), ['a.txt']);
    });
  });

  group('glob', () {
    test('matches on the relative posix path', () async {
      await wsFile('src/a.dart', 'x');
      await wsFile('src/deep/b.dart', 'x');
      await wsFile('src/c.txt', 'x');
      final r = await tools.glob('**/*.dart');
      expect(r.hits.map((e) => e.modelPath), ['/workspace/src/a.dart', '/workspace/src/deep/b.dart']);
    });

    test('dot directories are skipped unless asked for', () async {
      await wsFile('.git/config', 'x');
      await wsFile('src/a.dart', 'x');
      expect((await tools.glob('**/*')).hits, hasLength(1));
      // a pattern that starts with a dot opts back in
      final hidden = await tools.glob('**/.git/*');
      expect(hidden.hits.map((e) => e.modelPath), ['/workspace/.git/config']);
    });

    test('the cap trips', () async {
      for (var i = 0; i < HostFileTools.globCap + 10; i++) {
        await wsFile('g/f${i.toString().padLeft(4, '0')}.dart', 'x');
      }
      final r = await tools.glob('**/*.dart');
      expect(r.hits, hasLength(HostFileTools.globCap));
      expect(r.truncated, isTrue);
    });
  });

  group('grep', () {
    test('reports path line and text', () async {
      await wsFile('a.txt', 'alpha\nbeta\ngamma');
      final r = await tools.grep('beta');
      expect(r.matches, hasLength(1));
      expect(r.matches.first.line, 2);
      expect(r.matches.first.text, 'beta');
      expect(r.matches.first.modelPath, '/workspace/a.txt');
    });

    test('case sensitivity is a switch', () async {
      await wsFile('a.txt', 'Beta\nbeta');
      expect((await tools.grep('beta')).matches, hasLength(1));
      expect((await tools.grep('beta', ignoreCase: true)).matches, hasLength(2));
    });

    test('an invalid regex becomes a literal search', () async {
      await wsFile('a.txt', 'a(b\nplain');
      final r = await tools.grep('a(b');
      expect(r.matches.map((e) => e.text), ['a(b']);
    });

    test('binary files are skipped', () async {
      await File('${tmp.path}/ws/bin.dat').writeAsBytes([0, 1, 2, 0]);
      await wsFile('a.txt', 'needle');
      final r = await tools.grep('needle');
      expect(r.matches, hasLength(1));
    });

    test('the limit is respected and reported', () async {
      await wsFile('many.txt', List.generate(50, (i) => 'hit $i').join('\n'));
      final r = await tools.grep('hit', limit: 10);
      expect(r.matches, hasLength(10));
      expect(r.truncated, isTrue);
    });
  });

  group('diff', () {
    test('an unchanged file has no diff', () {
      expect(unifiedDiff('a\nb', 'a\nb', 'f'), isEmpty);
    });

    test('a single line change is one hunk', () {
      final d = unifiedDiff('a\nb\nc\nd\ne\nf\ng\nh', 'a\nb\nc\nD\ne\nf\ng\nh', 'f');
      expect(d, contains('-d'));
      expect(d, contains('+D'));
      expect(d, contains('@@'));
      // untouched neighbours come along as context, the far ends do not
      expect(d, contains(' c'));
      expect(d, isNot(contains('-a')));
    });

    test('two far apart changes make two hunks', () {
      final before = List.generate(40, (i) => 'line $i').join('\n');
      final after = before.replaceFirst('line 2', 'LINE 2').replaceFirst('line 35', 'LINE 35');
      final d = unifiedDiff(before, after, 'f');
      // a hunk header carries two @@ so count the line starts, not the symbol
      expect(RegExp(r'^@@', multiLine: true).allMatches(d).length, 2);
    });

    test('counts line up', () {
      expect(diffCounts('a\nb\nc', 'a\nx\ny\nc'), (added: 2, removed: 1));
      expect(diffCounts('a', 'a'), (added: 0, removed: 0));
    });

    test('a huge change truncates instead of printing everything', () {
      final before = List.generate(5000, (i) => 'a$i').join('\n');
      final after = List.generate(5000, (i) => 'b$i').join('\n');
      final d = unifiedDiff(before, after, 'f');
      expect(d, contains('diff truncated'));
      expect(d.length, lessThan(40000));
    });

    test('a big but mostly unchanged file diffs without hanging', () {
      final before = List.generate(6000, (i) => 'line $i').join('\n');
      final after = before.replaceFirst('line 3000', 'changed');
      final d = unifiedDiff(before, after, 'f');
      expect(d, contains('+changed'));
    });

    test('crlf does not print a carriage return', () {
      final d = unifiedDiff('a\r\nb', 'a\r\nc', 'f');
      expect(d.contains('\r'), isFalse);
    });
  });

  group('applyEdit', () {
    test('empty old text is refused', () {
      expect(HostFileTools.applyEdit('a', '', 'b').ok, isFalse);
    });

    test('a trailing newline in old_text still matches', () {
      final r = HostFileTools.applyEdit('one\ntwo\n', 'two\n', 'TWO\n');
      expect(r.ok, isTrue);
      expect(r.updated, 'one\nTWO\n');
    });
  });
}