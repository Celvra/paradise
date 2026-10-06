import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/workspace/workspace_paths.dart';
import 'package:path/path.dart' as path_lib;

// The sandbox. Every case here is a way a model could reach something it was not
// offered, so they are written as attacks rather than as API calls.

void main() {
  late Directory tmp;
  late String wsRoot;
  late String chatRoot;
  late String skillsRoot;
  late String tmpRoot;
  late String outside;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ws_paths');
    // p.join, not string interpolation: the lib returns package:path form
    // (backslashes on Windows, forward slashes elsewhere) and a hand-built
    // expected path with mixed separators never matches on one of the two
    wsRoot = path_lib.join(tmp.path, 'ws');
    chatRoot = path_lib.join(tmp.path, 'chat');
    skillsRoot = path_lib.join(tmp.path, 'skills');
    tmpRoot = path_lib.join(tmp.path, 'tmp');
    outside = path_lib.join(tmp.path, 'outside');
    for (final d in [wsRoot, chatRoot, skillsRoot, tmpRoot, outside]) {
      await Directory(d).create(recursive: true);
    }
    await File('$outside/secret.txt').writeAsString('secret');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  WorkspacePaths paths({String cwd = WorkspacePaths.guestWorkspace, List<ExternalMount> mounts = const []}) => WorkspacePaths.sandboxed(
        workspaceHostRoot: wsRoot,
        chatHostRoot: chatRoot,
        skillsHostRoot: skillsRoot,
        tmpHostRoot: tmpRoot,
        cwd: cwd,
        externalMounts: mounts,
      );

  bool refused(WorkspacePaths p, String path, {String? cwd}) {
    try {
      p.resolve(path, cwd: cwd);
      return false;
    } on PathResolutionException {
      return true;
    }
  }

  group('lexical', () {
    test('maps each zone root', () {
      final p = paths();
      expect(p.resolve('/workspace/a.txt').hostPath, path_lib.join(wsRoot, 'a.txt'));
      expect(p.resolve('/workspace').hostPath, wsRoot);
      expect(p.resolve('/workspace/a.txt').zone, WorkspaceZone.workspace);
      expect(p.resolve('/chat/attachments/x.png').hostPath, path_lib.join(chatRoot, 'attachments', 'x.png'));
      expect(p.resolve('/chat/attachments/x.png').zone, WorkspaceZone.chat);
      expect(p.resolve('/tmp/scratch').zone, WorkspaceZone.tmp);
      expect(p.resolve('/skills/k/SKILL.md').zone, WorkspaceZone.skills);
    });

    test('a relative path lands under the cwd', () {
      final p = paths(cwd: '/workspace/sub');
      expect(p.resolve('notes.md').hostPath, path_lib.join(wsRoot, 'sub', 'notes.md'));
    });

    test('a dotted cwd means the root', () {
      expect(paths(cwd: '.').normalizeCwd(''), '/workspace');
      expect(paths().normalizeCwd('/workspace/a'), '/workspace/a');
    });

    test('a null byte is refused outright', () {
      expect(refused(paths(), '/workspace/a\x00b'), isTrue);
    });
  });

  group('escapes', () {
    test('an absolute host path is not a zone path', () {
      expect(refused(paths(), '/etc/passwd'), isTrue);
    });

    test('dot dot out of the workspace is refused', () {
      expect(refused(paths(), '/workspace/../etc/passwd'), isTrue);
      expect(refused(paths(), '/workspace/a/../../etc/passwd'), isTrue);
    });

    test('dot dot that stays inside the zone is allowed', () {
      // the reason the anchor is classified rather than the normalized path:
      // this stays a workspace write while the one above is not
      expect(paths().resolve('/workspace/a/../b.txt').hostPath, path_lib.join(wsRoot, 'b.txt'));
    });

    test('a relative dot dot cannot climb above the root', () {
      expect(refused(paths(), '../../outside/secret.txt', cwd: '/workspace'), isTrue);
      expect(refused(paths(), '../secret.txt', cwd: '/workspace'), isTrue);
    });

    test('a sibling zone is not reachable by traversal', () {
      expect(refused(paths(), '/workspace/../skills/k/SKILL.md'), isTrue);
      expect(refused(paths(), '/tmp/../workspace/a'), isTrue);
    });

    test('a null byte cannot hide a traversal', () {
      expect(refused(paths(), '/workspace/\x00/../etc'), isTrue);
    });
  });

  group('symlinks', () {
    test('a link out of the workspace resolves back to outside', () async {
      final link = Link('$wsRoot/escape');
      await link.create(outside);
      // lexically it looks like a workspace path
      expect(paths().resolve('/workspace/escape/secret.txt').zone, WorkspaceZone.workspace);
      // after resolution it does not, which is what the write gate reads
      final real = await paths().resolveReal('/workspace/escape/secret.txt');
      expect(real.zone, WorkspaceZone.outside);
      expect(real.hostPath, path_lib.join(outside, 'secret.txt'));
    });

    test('a path that does not exist yet still resolves its parents', () async {
      // the tail below does not exist, the link above it does
      final target = path_lib.join(tmp.path, 'real');
      await Directory(target).create();
      await Link('$wsRoot/link').create(target);
      final real = await paths().resolveReal('/workspace/link/not/created/yet.txt');
      expect(real.hostPath, path_lib.join(target, 'not', 'created', 'yet.txt'));
    });

    test('a symlinked root still matches itself', () async {
      await Link('${tmp.path}/alias').create(wsRoot);
      final p = WorkspacePaths.sandboxed(
        workspaceHostRoot: '${tmp.path}/alias',
        chatHostRoot: chatRoot,
        skillsHostRoot: skillsRoot,
        tmpHostRoot: tmpRoot,
      );
      // resolve is lexical on purpose, it stays on the path it was handed and
      // never touches the disk. the zone check still matches because it compares
      // both the lexical and the resolved form of the root
      expect(p.resolve('/workspace/a.txt').hostPath, path_lib.join(tmp.path, 'alias', 'a.txt'));
      // resolveReal is the one that follows the link
      expect((await p.resolveReal('/workspace/a.txt')).hostPath, path_lib.join(wsRoot, 'a.txt'));
      expect((await p.resolveReal('/workspace/a.txt')).zone, WorkspaceZone.workspace);
    });
  });

  group('toModelPath', () {
    test('round trips a host path back to the model vocabulary', () {
      final p = paths();
      expect(p.toModelPath('$wsRoot/a/b.txt'), '/workspace/a/b.txt');
      expect(p.toModelPath(chatRoot), '/chat');
      expect(p.toModelPath('$skillsRoot/k'), '/skills/k');
      expect(p.toModelPath(tmpRoot), '/tmp');
    });

    test('an unclaimed host path stays a host path', () {
      // this is what leaves an outside file with no link behind it
      expect(paths().toModelPath(outside), outside);
    });
  });

  group('external mounts', () {
    late ExternalMount mountA;
    late ExternalMount mountB;

    setUp(() async {
      final mA = path_lib.join(tmp.path, 'mA');
      final mB = '${tmp.path}/mB';
      await Directory(mA).create(recursive: true);
      await Directory(mB).create(recursive: true);
      mountA = ExternalMount(id: 'a', name: 'a', hostPath: mA);
      mountB = ExternalMount(id: 'b', name: 'b', hostPath: mB);
    });

    test('maps into a mount', () {
      final p = paths(mounts: [mountA, mountB]);
      expect(p.resolve('/mounts/a/x.txt').hostPath, path_lib.join(mountA.hostPath, 'x.txt'));
      expect(p.resolve('/mounts/a/x.txt').zone, WorkspaceZone.external);
      expect(p.toModelPath('${mountA.hostPath}/x.txt'), '/mounts/a/x.txt');
    });

    test('a mount cannot be reached from another mount', () {
      expect(refused(paths(mounts: [mountA, mountB]), '/mounts/a/../b/x.txt'), isTrue);
    });

    test('a mount cannot be reached from a builtin zone', () {
      expect(refused(paths(mounts: [mountA, mountB]), '/workspace/../mounts/a/x.txt'), isTrue);
    });

    test('a read only mount reports read only', () {
      final ro = ExternalMount(id: 'r', name: 'r', hostPath: mountA.hostPath, readOnly: true);
      final p = paths(mounts: [ro]);
      expect(p.isReadOnlyPath('${mountA.hostPath}/x.txt'), isTrue);
      expect(p.isReadOnlyPath('$wsRoot/x.txt'), isFalse);
    });
  });

  group('zone policy', () {
    test('skills and outside are not writable zones', () {
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.workspace), isTrue);
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.chat), isTrue);
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.tmp), isTrue);
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.skills), isFalse);
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.outside), isFalse);
    });

    test('the skills root is read only', () {
      expect(paths().isReadOnlyPath('$skillsRoot/k/SKILL.md'), isTrue);
    });
  });

  // A fresh binding sends an empty cwd and the shell tool resolves that cwd
  // before every command, so an empty base used to classify the empty path as
  // outside and the first shell call failed with "path escapes a workspace
  // zone: " naming no path at all.
  group('the default cwd', () {
    test('an empty cwd is the workspace root, and resolves', () {
      final p = paths(cwd: '');
      expect(p.cwd, WorkspacePaths.guestWorkspace);
      expect(refused(p, ''), isFalse);
      expect(p.resolve('').modelPath, WorkspacePaths.guestWorkspace);
      expect(p.resolve('a.txt').hostPath, path_lib.join(wsRoot, 'a.txt'));
    });

    test('a dotted cwd is the root too', () {
      expect(paths(cwd: '.').cwd, WorkspacePaths.guestWorkspace);
    });

    test('a relative cwd is folded onto the root', () {
      final p = paths(cwd: 'sub');
      expect(p.cwd, '${WorkspacePaths.guestWorkspace}/sub');
      expect(p.resolve('a.txt').hostPath, path_lib.join(wsRoot, 'sub', 'a.txt'));
    });

    test('the prompt sees an absolute default, not a blank one', () {
      expect(paths(cwd: '').cwd, startsWith('/'));
    });
  });
}