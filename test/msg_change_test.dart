import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/models.dart';

/// Msg reports its own changes so storage can write the row back without a save
/// call at every call site. The in place container mutations are the reason this
/// is not just a pile of setters: `m.data['state'] = 'ok'` and `m.edits.add(old)`
/// both change a message that the storage layer would otherwise never hear about.
void main() {
  Msg fresh() => Msg(id: 'm1', out: false, text: 'hello', time: 1);

  group('field changes report themselves', () {
    test('every persisted field setter fires', () {
      final m = fresh();
      final fired = <String>[];
      m.onChange = (_) => fired.add('x');

      m.text = 'bye';
      m.state = St.read;
      m.recalled = true;
      m.recalledAfterRead = true;
      m.recalledText = 'old';
      m.edited = true;
      m.pinned = true;
      m.proactive = true;
      // read is a view over state, so this one only counts because state is
      // already read from the line above
      m.read = false;

      expect(fired.length, 9);
    });

    test('setting a field to what it already was is silent', () {
      // streaming text assigns on every chunk and the state flips between
      // sending and sent, so a redundant report would be a redundant write
      final m = fresh();
      var n = 0;
      m.onChange = (_) => n++;

      m.text = 'hello';
      m.state = m.state;
      m.recalled = false;
      m.pinned = false;
      expect(n, 0);

      m.text = 'different';
      expect(n, 1);
    });

    test('mutating data in place fires', () {
      final m = fresh();
      var n = 0;
      m.onChange = (_) => n++;

      // this is the streaming tool path, and it never reassigns the message
      m.data['body'] = 'partial';
      m.data['state'] = 'ok';
      expect(n, 2);
    });

    test('mutating edits in place fires', () {
      final m = fresh();
      var n = 0;
      m.onChange = (_) => n++;

      m.edits.add(m.text);
      m.text = 'new';
      expect(n, 2);
    });

    test('reading data does not fire', () {
      final m = fresh();
      var n = 0;
      m.onChange = (_) => n++;

      expect(m.data.containsKey('nope'), isFalse);
      expect(m.data['nope'], isNull);
      expect(m.edits, isEmpty);
      expect(m.haystack, isNotEmpty);
      expect(n, 0);
    });

    test('removing nothing from data is silent', () {
      final m = fresh();
      var n = 0;
      m.onChange = (_) => n++;

      expect(m.data.remove('absent'), isNull);
      m.data.clear();
      expect(n, 0);

      m.data['a'] = 1;
      expect(m.data.remove('a'), 1);
      expect(n, 2);
    });
  });

  group('json', () {
    test('a message survives a round trip with every flag', () {
      final m = Msg(
        id: 'm1',
        out: true,
        text: 'body',
        time: 99,
        reply: 'm0',
        state: St.read,
        kind: MsgKind.photo,
        service: false,
        data: {'w': 1, 'h': 2},
        recalled: true,
        recalledAfterRead: true,
        recalledText: 'gone',
        edited: true,
        edits: const ['first', 'second'],
        pinned: true,
        proactive: true,
      );

      final back = Msg.fromJson(m.toJson());
      expect(back.id, 'm1');
      expect(back.out, isTrue);
      expect(back.text, 'body');
      expect(back.time, 99);
      expect(back.reply, 'm0');
      expect(back.read, isTrue);
      expect(back.kind, MsgKind.photo);
      expect(back.data, {'w': 1, 'h': 2});
      expect(back.recalled, isTrue);
      expect(back.recalledAfterRead, isTrue);
      expect(back.recalledText, 'gone');
      expect(back.edited, isTrue);
      expect(back.edits, ['first', 'second']);
      expect(back.pinned, isTrue);
      expect(back.proactive, isTrue);
    });

    test('a gift message keeps its kind and data across a save', () {
      // the shop card must survive an update or a restore: a missing case in
      // the kind switch silently turned it back into an empty text bubble
      final m = Msg(id: 'g1', out: true, text: '', time: 1, kind: MsgKind.gift, data: {'item': 'i1', 'title': 'Coffee', 'effect': 'energy'});
      final back = Msg.fromJson(m.toJson());
      expect(back.kind, MsgKind.gift);
      expect(back.data['title'], 'Coffee');
      expect(back.data['effect'], 'energy');
    });

    test('a message read from storage does not report while it is being built', () {
      // the constructor fills fields before there is a listener, so a load must
      // not turn into a write of everything it just read
      var n = 0;
      final m = Msg.fromJson({'id': 'a', 'out': false, 'text': 't', 'time': 1});
      m.onChange = (_) => n++;
      expect(n, 0);
    });
  });
}