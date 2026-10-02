import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/human/br_parser.dart';

/// Runs a whole turn through the parser the way the engine does and returns
/// what would have reached the chat.
List<BrSegment> feed(List<String> chunks, {BrParser? parser}) {
  final p = parser ?? BrParser();
  final out = <BrSegment>[];
  for (final c in chunks) {
    out.addAll(p.push(c));
  }
  out.addAll(p.finish());
  return out;
}

List<String> texts(List<BrSegment> segs) => [for (final s in segs) s.text];

void main() {
  group('the tag the model was told to write', () {
    test('cuts the answer at the break', () {
      final segs = feed(['自己是真的<i-br_800>下午还有事吗']);
      expect(texts(segs), ['自己是真的', '下午还有事吗']);
      expect(segs.first.delayMs, 800);
    });

    test('a bare tag waits for the default', () {
      final segs = feed(['自己是真的<i-br>没事<i-br>睡了']);
      expect(texts(segs), ['自己是真的', '没事', '睡了']);
      expect(segs.first.delayMs, 600);
    });

    test('the placeholder copied out of the prompt is still a break', () {
      // "or <i-br_MS> to wait MS milliseconds" used to leak into the bubble and
      // left the rest of the turn unsplit
      final segs = feed(['自己是真的<i-br_MS>下午还有事吗']);
      expect(texts(segs), ['自己是真的', '下午还有事吗']);
      expect(segs.first.delayMs, 600);
      expect(segs.first.explicit, false);
    });

    test('spacing, a missing underscore and a self closing slash all cut', () {
      for (final tag in ['<i-br 800>', '<i-br800>', '<i-br_800/>', '<I-BR_800>', '<i-br_MS_800>', '<i-brMS>']) {
        final segs = feed(['自己是真的$tag 下午']);
        expect(texts(segs), ['自己是真的', '下午'], reason: tag);
        expect(segs.first.delayMs, isNot(0), reason: tag);
      }
    });

    test('a silly pause is clamped instead of rejected', () {
      final segs = feed(['自己是真的<i-br_10000000>下午']);
      expect(texts(segs), ['自己是真的', '下午']);
      expect(segs.first.delayMs, 8000);
    });

    test('no raw tag ever reaches the text', () {
      for (final tag in ['<i-br>', '<i-br_800>', '<i-br_MS>', '<i-br 800>', '<i-br800>', '<i-br/>']) {
        expect(stripBrTags('自己是真的$tag 下午'), '自己是真的 下午', reason: tag);
      }
      // not a tag, ordinary text
      expect(stripBrTags('a < b and <i-bracket> stays'), 'a < b and <i-bracket> stays');
    });
  });

  group('a model that forgot the tag and used empty lines', () {
    test('an empty line is a break with the default pause', () {
      final segs = feed(['陪你聊天啊\n\n发呆也算一种技能吧']);
      expect(texts(segs), ['陪你聊天啊', '发呆也算一种技能吧']);
      expect(segs.first.delayMs, 600);
      expect(segs.first.explicit, isFalse);
    });

    test('the real turn that came in, verbatim', () {
      final segs = feed(['陪你聊天啊\n\n发呆也算一种技能吧\n\n你要是有事也可以跟我说说\n\n不过我可能帮不上忙，就是听着\n\n比如呢，你现在在干嘛']);
      expect(texts(segs), ['陪你聊天啊', '发呆也算一种技能吧', '你要是有事也可以跟我说说', '不过我可能帮不上忙，就是听着', '比如呢，你现在在干嘛']);
    });

    test('blanks between the two newlines are still one empty line', () {
      expect(texts(feed(['a\n \t \nb'])), ['a', 'b']);
      expect(texts(feed(['a\r\n\r\nb'])), ['a', 'b']);
    });

    test('a single newline stays inside the bubble', () {
      expect(texts(feed(['第一行\n还是同一条'])), ['第一行\n还是同一条']);
    });

    test('an empty line inside a code fence is text, one after it is not', () {
      // the fence keeps its own blank lines, the empty line that closes the
      // fence is ordinary text again and does split
      expect(texts(feed(['```\n\ncode\n\n```\n\n真话'])), ['```\n\ncode\n\n```', '真话']);
    });

    test('tags off means one segment', () {
      expect(texts(feed(['陪你聊天啊\n\n发呆也算一种技能吧'], parser: BrParser(enabled: false))), ['陪你聊天啊\n\n发呆也算一种技能吧']);
    });

    test('an edited message is split the same way a streamed one was', () {
      expect(splitBrText('陪你聊天啊\n\n发呆也算一种技能吧'), ['陪你聊天啊', '发呆也算一种技能吧']);
    });

    test('a tag after an empty line does not double the pause', () {
      final segs = feed(['a\n\nb<i-br_1200>c']);
      expect(texts(segs), ['a', 'b', 'c']);
      expect(segs[0].delayMs, 600);
      expect(segs[1].delayMs, 1200);
    });

    test('a trailing empty line at the end of a turn is not a message', () {
      expect(texts(feed(['a\n\n'])), ['a']);
    });
  });

  group('text that is not a tag', () {
    test('a lone angle bracket is text', () {
      expect(texts(feed(['自己是真的<下午'])), ['自己是真的<下午']);
    });

    test('a half written tag at the end is dropped, the sentence stays', () {
      expect(texts(feed(['自己是真的<i-br_8'])), ['自己是真的']);
    });

    test('inside a code fence the tag is text', () {
      // the point is that a tag written inside a fence is never interpreted.
      // The newline after the closing fence is a break like any other, so the
      // line that follows lands as its own bubble.
      final segs = feed(['```\n<i-br_800>\n```\n真的']);
      expect(texts(segs), ['```\n<i-br_800>\n```', '真的']);
      // and the fence itself kept the tag verbatim rather than cutting on it
      expect(segs.first.text, contains('<i-br_800>'));
      expect(segs.first.delayMs, 600);
    });

    test('two tags in a row add their pauses onto the next bubble', () {
      final segs = feed(['<i-br_800><i-br_900>自己是真的']);
      expect(texts(segs), ['自己是真的']);
      expect(segs.first.delayMs, 1700);
    });

    test('a tag in front of the first bubble is a pause, not into nowhere', () {
      final segs = feed(['<i-br_800>自己是真的']);
      expect(texts(segs), ['自己是真的']);
      expect(segs.first.delayMs, 800);
    });

    test('tags off means one segment', () {
      final p = BrParser(enabled: false);
      expect(texts(feed(['自己是真的<i-br_800>下午'], parser: p)), ['自己是真的<i-br_800>下午']);
    });
  });

  group('a stream that stops in the middle', () {
    test('finish hands the tail over', () {
      final p = BrParser();
      final first = p.push('自己是真的<i-br_800>下午还有事');
      expect(texts(first), ['自己是真的']);
      expect(texts(p.finish()), ['下午还有事']);
    });

    test('release hands the tail over too, so a dead connection keeps the answer', () {
      final p = BrParser();
      final first = p.push('自己是真的<i-br_800>下午还有事');
      expect(texts(first), ['自己是真的']);
      expect(texts(p.release()), ['下午还有事']);
      // nothing may come out of a parser that was released
      expect(p.push('还有'), isEmpty);
      expect(p.finish(), isEmpty);
    });

    test('release after an interrupt stays silent', () {
      final p = BrParser();
      p.push('自己是真的<i-br_800>下午');
      final cut = p.abort();
      expect(cut.droppedText.trim(), '下午');
      expect(p.release(), isEmpty);
      expect(p.finish(), isEmpty);
    });
  });

  group('splitBrText, used when a message is edited', () {
    test('splits without any timing', () {
      expect(splitBrText('早上好。<i-br_500>今天心情如何?'), ['早上好。', '今天心情如何?']);
      expect(splitBrText('没有标签'), ['没有标签']);
      expect(splitBrText('<i-br_800>'), isEmpty);
    });
  });
}