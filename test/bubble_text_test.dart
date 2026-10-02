import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/store.dart';

/// What the model wrote, before it is shown. These are the two leaks that used
/// to reach a bubble: a break tag the parser did not understand, and the
/// [m:abc123 14:02] ids the model copies out of its own history.
void main() {
  group('a bubble is cleaned before anyone sees it', () {
    test('a leaked break tag goes', () {
      expect(cleanBubble('自己是真的<i-br_MS> 下午'), '自己是真的 下午');
      expect(cleanBubble('<i-br_500>'), '');
    });

    test('an id at the start of a bubble goes', () {
      expect(cleanBubble('[m:702_16 19:08] 你要是有事也可以跟我说说'), '你要是有事也可以跟我说说');
    });

    test('an id in the middle of a bubble goes too', () {
      // this one came out of a real turn, the model was labelling who says what
      final got = cleanBubble('陪你聊天啊\n\n发呆也算一种技能吧\n\n[m:702_16 19:08] 你要是有事也可以跟我说说\n\n不过我可能帮不上忙，就是听着\n\n[m:118_17 19:08] 比如呢，你现在在干嘛');
      expect(got, '陪你聊天啊\n\n发呆也算一种技能吧\n\n你要是有事也可以跟我说说\n\n不过我可能帮不上忙，就是听着\n\n比如呢，你现在在干嘛');
      expect(got.contains('[m:'), isFalse);
    });

    test('the space an id left behind is closed up', () {
      expect(cleanBubble('早上好 [m:702_16 19:08] 吃了没'), '早上好 吃了没');
      expect(cleanBubble('早上好[m:702_16 19:08]吃了没'), '早上好吃了没');
    });

    test('text that only looks like an id stays', () {
      expect(cleanBubble('数组 m:[1,2] 这样写'), '数组 m:[1,2] 这样写');
      expect(cleanBubble('see [matrix: 3x3]'), 'see [matrix: 3x3]');
      expect(cleanBubble('版本 v:m:12 挺好'), '版本 v:m:12 挺好');
      // a line that only looks like a time after a word is text
      expect(cleanBubble('speed m:8 12:30 左右'), 'speed m:8 12:30 左右');
    });

    test('a mangled prefix goes too, the model never writes it the same way twice', () {
      // three real shapes: both square, opening turned into an angle bracket,
      // closing one instead
      expect(cleanBubble('[m:5012_9 19:29] 人类多累'), '人类多累');
      expect(cleanBubble('<m:5012_9 19:29] 人类多累'), '人类多累');
      expect(cleanBubble('[m:5012_9 19:29> 人类多累'), '人类多累');
      expect(cleanBubble('<m:5012_9 19:29> 人类多累'), '人类多累');
      // no brackets at all, a line of its own
      expect(cleanBubble('m:5012_9 19:29\n人类多累'), '人类多累');
      expect(cleanBubble('前面那句\nm:5012_9 19:29 人类多累'), '前面那句\n人类多累');
      // one id in the middle, one on the next line, at once
      expect(cleanBubble('陪你聊天啊\n[m:702_16 19:08] 你要是有事也可以跟我说说\n<m:118_17 19:08] 比如呢'), '陪你聊天啊\n你要是有事也可以跟我说说\n比如呢');
    });

    test('ordinary text is left alone', () {
      expect(cleanBubble('陪你聊天啊'), '陪你聊天啊');
      expect(cleanBubble('a < b and 1 < 2'), 'a < b and 1 < 2');
      expect(cleanBubble('空行\n\n还在'), '空行\n\n还在');
      // a run of blank lines is tidied but never lost
      expect(cleanBubble('前\n\n\n\n后'), '前\n\n后');
    });
  });
}