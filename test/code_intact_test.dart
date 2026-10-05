import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/segmenter.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/ui/workspace/preview_kind.dart';

// code the model sends has to arrive whole. These pin the three places a code
// block used to be cut apart: the character-mode segmenter, the markdown strip
// and the bubble cleaner.
void main() {
  group('stripMarkdown keeps fences', () {
    test('a fenced block survives the strip with its language label', () {
      final src = '看这个\n```python\nprint("hi")\n```\n完了';
      final got = stripMarkdown(src);
      expect(got, contains('```python'));
      expect(got, contains('print("hi")'));
      expect(got, contains('看这个'));
    });

    test('emphasis inside prose is stripped, inside a fence it is not', () {
      final src = '**粗**\n```js\nconst a = **not emphasis**;\n```\n*斜*';
      final got = stripMarkdown(src);
      expect(got, contains('粗'));
      expect(got, isNot(contains('**粗**')));
      expect(got, contains('const a = **not emphasis**;'));
    });

    test('indentation inside a fence survives', () {
      final src = '```\nif ok:\n    return deep\n```';
      expect(stripMarkdown(src), contains('\n    return deep'));
    });
  });

  group('the segmenter keeps a fenced block as one bubble', () {
    test('a fence with newlines and long lines is never split mid-body', () {
      final s = Segmenter(strip: true, random: Random(0));
      final code = '```python\ndef f():\n    x = 1\n    return x\n```\n';
      final out = s.push('前面一句话。\n$code');
      final tail = s.flush();
      final all = [...out, ...tail];
      // the prose ahead may be its own bubble but the fence body lands whole
      final codeBubbles = all.where((b) => b.contains('```')).toList();
      expect(codeBubbles, hasLength(1));
      expect(codeBubbles.first, contains('return x'));
      expect(codeBubbles.first, startsWith('```python'));
    });

    test('prose ahead of a fence still cuts normally', () {
      final s = Segmenter(strip: true, random: Random(1));
      final out = s.push('第一句。\n第二句。\n```\ncode line\n```\n');
      final tail = s.flush();
      final all = [...out, ...tail];
      expect(all.first, contains('第一句'));
      final codeBubble = all.firstWhere((b) => b.contains('```'));
      expect(codeBubble, contains('code line'));
    });

    test('an unclosed fence lands as one final bubble', () {
      final s = Segmenter(strip: true, random: Random(2));
      s.push('先说一句。\n```\nstill code\nmore code');
      final all = s.flush();
      expect(all.join('\n'), contains('still code'));
      // nothing was lost, the fence body is intact in one bubble
      final codeBubble = all.firstWhere((b) => b.contains('still code'));
      expect(codeBubble, contains('more code'));
    });
  });

  group('cleanBubble keeps code', () {
    test('indentation inside a fence is not collapsed', () {
      final src = '```python\nif a:\n    return b\n```';
      expect(cleanBubble(src), contains('\n    return b'));
    });

    test('prose spacing is still collapsed outside a fence', () {
      expect(cleanBubble('你好    世界'), '你好 世界');
    });

    test('a closed fence stops the exemption', () {
      final got = cleanBubble('```\ncode  kept\n```\n散文    收紧');
      expect(got, contains('code  kept'));
      expect(got, contains('散文 收紧'));
    });
  });

  group('preview kinds for sent documents', () {
    test('html and svg route to the rendered preview', () {
      expect(previewKindFor('page.html'), PreviewKind.html);
      expect(previewKindFor('page.htm'), PreviewKind.html);
      expect(previewKindFor('icon.svg'), PreviewKind.html);
    });
  });
}

