import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paradise/data/models.dart';
import 'package:paradise/data/skills/skill.dart';
import 'package:paradise/data/skills/skill_prompt.dart';
import 'package:paradise/data/skills/skill_store.dart';
import 'package:paradise/data/store.dart';

const _md = '''---
name: Pdf Tools
description: Extract text and tables from PDF files.
---

# Pdf Tools

Do the thing.
''';

Future<SkillStore> _store(Directory dir) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  return SkillStore.load(sp, dir: dir);
}

void main() {
  group('skill document', () {
    test('parses frontmatter and validates', () {
      final doc = SkillDoc.parse(_md);
      expect(doc.name, 'Pdf Tools');
      expect(doc.description, 'Extract text and tables from PDF files.');
      expect(doc.validate(), isEmpty);
    });

    test('missing fields are reported', () {
      expect(SkillDoc.parse('just words').validate(), isNotEmpty);
      expect(SkillDoc.parse('---\nname: x\n---\nbody').validate(), contains('missing description'));
    });

    test('falls back to the first heading for the name', () {
      final doc = SkillDoc.parse('# Helper\n\nDoes things.');
      expect(doc.name, 'Helper');
    });

    test('slugify is stable and bounded', () {
      expect(skillSlug('Pdf Tools'), 'pdf-tools');
      expect(skillSlug('  ...  '), 'skill');
      expect(skillSlug('A' * 100).length, lessThanOrEqualTo(64));
    });

    test('descriptions clip without splitting emoji', () {
      final clipped = clipDescription('${'a' * 190}${'😀' * 20}bbbb', 200);
      expect(clipped.characters.length, lessThanOrEqualTo(200));
      expect(clipped, isNot(contains('bbbb')));
    });
  });

  group('listing fragment', () {
    Skill skill(String id, {int useCount = 0, String description = 'does things'}) {
      final now = DateTime.utc(2026, 1, 1);
      return Skill(id: id, name: id, description: description, dir: '/tmp/$id', mdPath: '/tmp/$id/SKILL.md', enabled: true, useCount: useCount, source: SkillSource.paste, installedAt: now, updatedAt: now);
    }

    test('names the reader tool and every id', () {
      final fragment = buildAvailableSkillsFragment([skill('pdf-tools')]);
      expect(fragment, contains('<available_skills>'));
      expect(fragment, contains('read_skill'));
      expect(fragment, contains('pdf-tools'));
      expect(fragment.trimRight(), endsWith('</available_skills>'));
    });

    test('caps at twenty, most used first', () {
      final skills = [for (var i = 0; i < 21; i++) skill('s${i.toString().padLeft(2, '0')}', useCount: i == 7 ? 5 : 0)];
      final fragment = buildAvailableSkillsFragment(skills);
      expect(RegExp(r'^- ', multiLine: true).allMatches(fragment).length, 20);
      expect(fragment.split('\n').firstWhere((l) => l.startsWith('- ')), startsWith('- s07'));
    });
  });

  group('skill store', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('skills-test');
    });

    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('paste import, enable switch, read and delete', () async {
      final store = await _store(dir);
      final skill = await store.importFromText(_md);
      expect(skill.id, 'pdf-tools');
      expect(store.skills.length, 1);

      await store.setEnabled(skill.id, false);
      expect(store.resolveFor(null), isEmpty);
      await store.setEnabled(skill.id, true);
      expect(store.resolveFor(null).length, 1);

      final body = await store.readSkill(skill.id);
      expect(body, contains('Do the thing.'));
      expect(store.byId(skill.id)!.useCount, 1);

      await store.delete(skill.id);
      expect(store.skills, isEmpty);
    });

    test('a role filter names exactly its skills', () async {
      final store = await _store(dir);
      await store.importFromText(_md);
      await store.importFromText('---\nname: Helper\ndescription: Helps out.\n---\nbody');
      expect(store.resolveFor(null).length, 2);
      expect(store.resolveFor(['pdf-tools']).map((s) => s.id), ['pdf-tools']);
      expect(store.resolveFor([]), isEmpty);
      // unknown ids are dropped, never crash the prompt
      expect(store.resolveFor(['pdf-tools', 'gone']).map((s) => s.id), ['pdf-tools']);
    });

    test('a duplicate name gets a numbered id', () async {
      final store = await _store(dir);
      final a = await store.importFromText(_md);
      final b = await store.importFromText(_md);
      expect(a.id, 'pdf-tools');
      expect(b.id, 'pdf-tools-2');
    });

    test('an invalid document is refused', () async {
      final store = await _store(dir);
      expect(() => store.importFromText('nothing here'), throwsFormatException);
    });
  });

  group('role binding', () {
    test('skill ids round trip through json, missing means follow global', () async {
      final p = Persona(name: 'A', prompt: 'p', color: 1);
      expect(p.skillIds, isNull);
      final plain = Persona.fromJson({'name': 'A', 'prompt': 'x', 'color': 1});
      expect(plain.skillIds, isNull);

      p.skillIds = ['a', 'b'];
      final back = Persona.fromJson(p.toJson());
      expect(back.skillIds, ['a', 'b']);
    });

    test('the listing follows the role filter and the tool gate', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final chat = st.createChat('A', 'be helpful');
      // no skills installed: nothing injected, no tool
      expect(st.skillFragmentFor(chat), isEmpty);
      expect(st.skillToolFor(chat), isNull);

      final skill = await st.skills.importFromText(_md);
      // the humanized layer is on by default and always carries tools,
      // so the role sees the skill right away
      expect(st.skillFragmentFor(chat), contains(skill.id));
      expect(st.skillToolFor(chat), isNotNull);

      // with the humanized layer off and agent mode off, the listing is
      // withheld because the model would have no reader tool to open with
      st.human!.settings.enabled = false;
      expect(st.agentFor(chat), false);
      expect(st.skillFragmentFor(chat), isEmpty);

      // agent mode on: the role sees it again
      st.setAgentMode(true);
      expect(st.skillFragmentFor(chat), contains(skill.id));
      expect(st.skillToolFor(chat), isNotNull);

      // the role opts out entirely
      st.setPersonaSkills(chat, []);
      expect(st.skillFragmentFor(chat), isEmpty);

      // back to following the global set
      st.setPersonaSkills(chat, null);
      expect(st.skillFragmentFor(chat), contains(skill.id));
    });
  });
}
