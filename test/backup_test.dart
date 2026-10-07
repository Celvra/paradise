import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/backup.dart';

/// A backup is the one file a user is likely to keep for years and hand to
/// somebody else, so what it accepts and what it refuses matters as much as what
/// it writes.
void main() {
  Map<String, dynamic> chat(String id, {int msgs = 1}) => {
        'id': id,
        'persona': {'name': 'p', 'prompt': 'x', 'color': 0},
        'msgs': [
          for (var i = 0; i < msgs; i++) {'id': 'm$i', 'out': false, 'text': 't$i', 'time': i},
        ],
        'unread': 0,
      };

  group('writing', () {
    test('the envelope carries a kind and a version', () {
      final raw = buildBackup(chats: [chat('a')], personas: []);
      final j = parseBackup(raw);
      expect(j.version, 1);
      expect(raw.contains(backupKind), isTrue);
    });

    test('a document with nothing in it still parses', () {
      final j = parseBackup(buildBackup(chats: const [], personas: const []));
      expect(j.chats, isEmpty);
      expect(j.personas, isEmpty);
      expect(j.settings, isEmpty);
      expect(j.ai, isNull);
    });

    test('message counts across chats add up', () {
      final j = parseBackup(buildBackup(chats: [chat('a', msgs: 3), chat('b', msgs: 7)], personas: []));
      expect(j.chats.length, 2);
      expect(j.messageCount, 10);
    });

    test('the export is readable without this app', () {
      // indented json, not a packed one line blob
      final raw = buildBackup(chats: [chat('a')], personas: []);
      expect(raw, contains('\n  "kind"'));
      expect(raw.split('\n').length, greaterThan(5));
    });

    test('nothing that looks like a secret is written', () {
      final raw = buildBackup(
        chats: const [],
        personas: const [],
        ai: {
          'providers': [
            {'id': 'p1', 'name': 'OpenAI', 'baseUrl': 'https://api.openai.com/v1', 'apiKeyRef': 'p1'},
          ],
          'chain': [
            {'id': 'n1', 'providerId': 'p1', 'modelId': 'gpt-4o-mini'},
          ],
        },
      );
      // apiKeyRef names where a secret lives, it is not one, and this is the
      // whole reason the ai section can be included at all
      expect(raw, isNot(contains('sk-')));
      expect(raw, contains('apiKeyRef'));
      expect(parseBackup(raw).ai, isNotNull);
    });
  });

  group('reading', () {
    test('a file that is not json is refused with a readable message', () {
      expect(
        () => parseBackup('{oops'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('not valid JSON'))),
      );
    });

    test('a json file that is not ours is refused', () {
      expect(
        () => parseBackup('{"kind":"something.else","version":1}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('something.else'))),
      );
    });

    test('a backup from a newer build is refused rather than half read', () {
      // the alternative is importing a file whose sections this build would
      // silently skip, which looks like a successful restore that lost things
      final raw = buildBackup(chats: const [], personas: const []);
      final j = (jsonDecode(raw) as Map<String, dynamic>)..['version'] = backupVersion + 1;
      expect(
        () => parseBackup(jsonEncode(j)),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Update the app'))),
      );
    });

    test('a version of zero is refused', () {
      expect(() => parseBackup('{"kind":"$backupKind","version":0}'), throwsFormatException);
    });

    test('sections that are the wrong shape are ignored rather than fatal', () {
      final raw = jsonEncode({
        'kind': backupKind,
        'version': 1,
        'sections': {
          'chats': 'not a list',
          'personas': 42,
          'settings': 'not a map',
        },
      });
      final j = parseBackup(raw);
      expect(j.chats, isEmpty);
      expect(j.personas, isEmpty);
      expect(j.settings, isEmpty);
    });

    test('entries of the wrong type inside a list are dropped, the rest kept', () {
      final raw = jsonEncode({
        'kind': backupKind,
        'version': 1,
        'sections': {
          'chats': [
            chat('good'),
            'garbage',
            7,
          ],
        },
      });
      expect(parseBackup(raw).chats.map((c) => c['id']), ['good']);
    });

    test('the export time survives', () {
      final when = DateTime.fromMillisecondsSinceEpoch(1760000000000);
      final j = parseBackup(buildBackup(chats: const [], personas: const [], exportedAt: when));
      expect(j.exportedAt, when);
    });
  });

  group('choosing chats', () {
    test('a fresh restore takes everything', () {
      final doc = parseBackup(buildBackup(chats: [chat('a'), chat('b')], personas: const []));
      final r = selectChats(doc, const [], overwrite: false);
      expect(r.take.map((c) => c['id']), ['a', 'b']);
      expect(r.skipped, isEmpty);
    });

    test('without overwrite an existing chat is left alone', () {
      // restoring an old backup must not replace a conversation that has been
      // added to since, which is the whole reason this is not just take all
      final doc = parseBackup(buildBackup(chats: [chat('a'), chat('b')], personas: const []));
      final r = selectChats(doc, const ['a'], overwrite: false);
      expect(r.take.map((c) => c['id']), ['b']);
      expect(r.skipped.single, contains('already here'));
    });

    test('with overwrite it replaces', () {
      final doc = parseBackup(buildBackup(chats: [chat('a')], personas: const []));
      final r = selectChats(doc, const ['a'], overwrite: true);
      expect(r.take.map((c) => c['id']), ['a']);
      expect(r.skipped, isEmpty);
    });

    test('images, human and secrets sections survive the round trip', () {
      // the v1 additions are additive: a reader that predates them ignores
      // them, so they must parse back exactly as written
      final raw = buildBackup(
        chats: const [],
        personas: const [],
        images: const {'/old/avatar.png': {'b64': 'AAAA', 'name': 'avatar.png'}},
        human: const {'wallet': {'balance': 42.0, 'txs': []}},
        secrets: const {'prov_1': 'sk-xyz'},
      );
      final doc = parseBackup(raw);
      expect(doc.images, hasLength(1));
      expect((doc.images!['/old/avatar.png'] as Map)['b64'], 'AAAA');
      expect((doc.human!['wallet'] as Map)['balance'], 42.0);
      expect(doc.secrets!['prov_1'], 'sk-xyz');
    });

    test('sections written as absent parse back as null', () {
      final doc = parseBackup(buildBackup(chats: const [], personas: const []));
      expect(doc.images, isNull);
      expect(doc.human, isNull);
      expect(doc.secrets, isNull);
    });

    test('a chat with no id is reported rather than silently dropped', () {
      final doc = parseBackup(buildBackup(chats: [chat('a'), {'persona': {}}], personas: const []));
      final r = selectChats(doc, const [], overwrite: false);
      expect(r.take.length, 1);
      expect(r.skipped.single, contains('no id'));
    });
  });
}
