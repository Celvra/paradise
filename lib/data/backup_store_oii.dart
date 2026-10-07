part of 'store.dart';

/// The new multi-document OII archive. The original JSON document and the
/// first-generation backup.json ZIP remain readable through [BackupStore].
/// Remote uploads use the same [BackupStore.exportBackupArchive] entry point,
/// so no separate transport-specific format is necessary.
extension OiiBackupStore on Store {
  static const _assetBudget = 200 * 1024 * 1024;

  @visibleForTesting
  set debugBackupDocsDir(Directory? dir) => _debugBackupDocsDir = dir;

  @visibleForTesting
  Directory? get debugBackupDocsDir => _debugBackupDocsDir;

  Map<String, dynamic> _oiiSections() => {
        'chats': [for (final c in chats) c.toJson()],
        'personas': [for (final p in personas) p.toJson()],
        if (human != null) 'stickers': jsonDecode(human!.exportStickers()),
        if (human != null) 'memory': jsonDecode(human!.exportMemory()),
        'settings': exportSettings(),
        if (_ai != null) 'ai': _ai!.settings.toJson(),
        if (human != null)
          'human': {
            // MCP headers can contain bearer tokens. Like the remote target and
            // provider keys, they must not travel in a shareable archive.
            'settings': {...human!.settings.toJson(), 'mcp': <Object>[]},
            'tasks': human!.scheduler.toJson(),
            'wallet': human!.wallet.toJson(),
            if (_speech != null) 'speech': _speech!.toJson(),
          },
      };

  /// Visits only known local-asset fields. Never rewrite chat text, prompts,
  /// API addresses or other strings which happen to equal a file name.
  void _visitAssetFields(Map<String, dynamic> doc, String Function(String) replace) {
    void field(Map map, String key) {
      final v = map[key];
      if (v is String && v.startsWith('/')) map[key] = replace(v);
    }

    final settings = doc['settings'];
    if (settings is Map) field(settings, 'wallpaperPath');
    for (final c in (doc['chats'] as List? ?? const [])) {
      if (c is! Map) continue;
      field(c, 'wallpaperPath');
      final persona = c['persona'];
      if (persona is Map) field(persona, 'avatarPath');
      for (final m in (c['msgs'] as List? ?? const [])) {
        if (m is! Map) continue;
        final data = m['data'];
        if (data is Map) {
          field(data, 'path');
          field(data, 'thumb');
        }
      }
    }
    for (final p in (doc['personas'] as List? ?? const [])) {
      if (p is Map) field(p, 'avatarPath');
    }
    final stickers = doc['stickers'];
    if (stickers is Map) {
      for (final s in (stickers['items'] as List? ?? const [])) {
        if (s is! Map || s['kind'] == 'emoji') continue;
        field(s, 'value');
        field(s, 'thumb');
      }
    }
  }

  /// Roughly constant-time compared with reading every photo. Asset metadata
  /// participates in change detection so changing an avatar can trigger backup.
  Future<int> _oiiBackupFingerprint() async {
    var hash = _backupFingerprint();
    final paths = <String>{};
    _visitAssetFields(_oiiSections(), (path) {
      paths.add(path);
      return path;
    });
    for (final path in paths) {
      try {
        final stat = await File(path).stat();
        hash = (hash * 31 + path.hashCode + stat.size + stat.modified.millisecondsSinceEpoch) & 0x7fffffff;
      } catch (_) {
        // A removed or unreadable photo should not disable automatic backup.
        hash = (hash * 31 + path.hashCode) & 0x7fffffff;
      }
    }
    return hash;
  }

  /// OII v2, both for manual export and all automatic/remote targets.
  Future<Uint8List> exportOiiBackupArchive() async {
    // A deep copy ensures rewriting serialized paths does not touch live
    // observable maps, sticker entries, or any other Store state.
    final doc = jsonDecode(jsonEncode(_oiiSections())) as Map<String, dynamic>;
    final paths = <String>{};
    _visitAssetFields(doc, (path) {
      paths.add(path);
      return path;
    });
    final assets = <String, List<int>>{};
    final missing = <String>[];
    final location = <String, String>{};
    var total = 0;
    for (final path in paths) {
      try {
        final file = File(path);
        final size = await file.length();
        if (size > _assetBudget - total) {
          missing.add(path);
          continue;
        }
        final data = await file.readAsBytes();
        if (data.length > _assetBudget - total) {
          missing.add(path);
          continue;
        }
        final name = path.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final entry = 'files/${shaHex(data)}_${name.isEmpty ? 'asset' : name}';
        if (!assets.containsKey(entry)) {
          assets[entry] = data;
          total += data.length;
        }
        location[path] = entry;
      } catch (_) {
        missing.add(path);
      }
    }
    _visitAssetFields(doc, (path) => location[path] ?? path);
    final sections = <String, Map<String, Object?>>{
      'personas.oii': {'items': doc['personas']},
      'settings.oii': Map<String, Object?>.from(doc['settings'] as Map),
      if (doc['stickers'] is Map) 'stickers.oii': Map<String, Object?>.from(doc['stickers'] as Map),
      if (doc['memory'] is Map) 'memory.oii': Map<String, Object?>.from(doc['memory'] as Map),
      if (doc['ai'] is Map) 'ai.oii': Map<String, Object?>.from(doc['ai'] as Map),
      if (doc['human'] is Map) 'human.oii': Map<String, Object?>.from(doc['human'] as Map),
    };
    for (final c in doc['chats'] as List) {
      final map = Map<String, Object?>.from(c as Map);
      final entry = 'chats/${safeChatFileName('${map['id']}')}.oii';
      if (sections.containsKey(entry)) throw StateError('Duplicate chat archive entry: $entry');
      sections[entry] = map;
    }
    return buildBackupArchive(
      oiiFiles: sections,
      assets: assets,
      missing: missing,
      appVersion: appVersion,
    ).bytes;
  }

  /// Import after the dispatcher has identified `manifest.oii` in the ZIP.
  Future<BackupReport> importOiiBackupArchive(Uint8List bytes, {required bool overwrite}) async {
    final archive = parseBackupArchive(bytes);
    final report = BackupReport()
      ..warnings.addAll(archive.warnings)
      ..warnings.addAll(archive.missing.map((p) => 'file $p was missing at export'));
    if (!archive.docs.containsKey('personas.oii') || !archive.docs.containsKey('settings.oii')) {
      throw const FormatException('This OII backup is missing a required section.');
    }
    final base = _debugBackupDocsDir ?? await getApplicationDocumentsDirectory();
    final dir = await Directory('${base.path}/restored_assets/${DateTime.now().microsecondsSinceEpoch}').create(recursive: true);
    final moved = <String, String>{};
    for (final entry in archive.assets.entries) {
      final basename = entry.key.substring('files/'.length);
      // The parser validates entry names and hashes before we write anything.
      final f = File('${dir.path}/$basename');
      try {
        await f.writeAsBytes(entry.value, flush: true);
        moved[entry.key] = f.path;
        report.files++;
      } catch (_) {
        report.warnings.add('file ${entry.key}, could not be restored');
      }
    }
    // Restore relative paths only in the known asset fields, and report an
    // orphaned archive reference rather than silently keeping a broken path.
    final doc = <String, dynamic>{
      'chats': [for (final e in archive.docs.entries) if (e.key.startsWith('chats/')) jsonDecode(jsonEncode(e.value))],
      'personas': jsonDecode(jsonEncode(archive.docs['personas.oii']?['items'] ?? <Object>[])),
      'settings': jsonDecode(jsonEncode(archive.docs['settings.oii'])),
      if (archive.docs['stickers.oii'] != null) 'stickers': jsonDecode(jsonEncode(archive.docs['stickers.oii'])),
      if (archive.docs['memory.oii'] != null) 'memory': jsonDecode(jsonEncode(archive.docs['memory.oii'])),
      if (archive.docs['ai.oii'] != null) 'ai': jsonDecode(jsonEncode(archive.docs['ai.oii'])),
      if (archive.docs['human.oii'] != null) 'human': jsonDecode(jsonEncode(archive.docs['human.oii'])),
    };
    _visitAssetFields(doc, (path) => moved[path] ?? path);
    // Any `files/...` with no restored bytes must be visibly reported.
    void dangling(Map map, String key) {
      final v = map[key];
      if (v is String && v.startsWith('files/') && !moved.containsKey(v)) {
        report.warnings.add('file $v, missing from the archive');
      }
    }
    // The visitor intentionally restricts itself to rooted source paths;
    // the same field paths above carry relative archive paths on import.
    _visitArchiveAssetFields(doc, (map, key) {
      final v = map[key];
      if (v is String && v.startsWith('files/')) {
        dangling(map, key);
        map[key] = moved[v] ?? '';
      }
    });

    final oldDoc = buildBackup(
      chats: [for (final c in doc['chats'] as List) Map<String, dynamic>.from(c as Map)],
      personas: [for (final p in doc['personas'] as List) Map<String, dynamic>.from(p as Map)],
      stickers: doc['stickers'] is Map ? Map<String, dynamic>.from(doc['stickers'] as Map) : null,
      memory: doc['memory'] is Map ? Map<String, dynamic>.from(doc['memory'] as Map) : null,
      settings: Map<String, dynamic>.from(doc['settings'] as Map),
      ai: doc['ai'] is Map ? Map<String, dynamic>.from(doc['ai'] as Map) : null,
    );
    final restored = importBackupString(oldDoc, overwrite: overwrite);
    report
      ..chats = restored.chats
      ..messages = restored.messages
      ..personas = restored.personas
      ..stickers = restored.stickers
      ..memories = restored.memories
      ..settings = restored.settings
      ..ai = restored.ai
      ..warnings.addAll(restored.warnings);
    final humanSection = doc['human'];
    if (humanSection is Map) _applyOiiHuman(Map<String, dynamic>.from(humanSection), report);
    return report;
  }

  /// Imported singleton state was not part of the v1 JSON document.
  void _applyOiiHuman(Map<String, dynamic> data, BackupReport report) {
    final hub = human;
    if (hub == null) return;
    try {
      if (data['settings'] is Map) {
        final m = Map<String, dynamic>.from(data['settings'] as Map);
        // Credentials and MCP servers belong to this device. Keep its list.
        m['mcp'] = hub.settings.toJson()['mcp'];
        hub.settings = HumanSettings.fromJson(m);
        report.human = true;
      }
      if (data['tasks'] is List) {
        hub.scheduler.loadJson(data['tasks'] as List);
        report.tasks = (data['tasks'] as List).length;
      }
      if (data['wallet'] is Map) {
        hub.wallet.loadJson(Map<String, dynamic>.from(data['wallet'] as Map));
        report.wallet = true;
      }
      hub.changed();
    } catch (_) {
      report.warnings.add('human settings, tasks or wallet could not be restored');
    }
    final voice = _speech;
    final speech = data['speech'];
    if (voice != null && speech is Map) {
      try {
        final s = Map<String, dynamic>.from(speech);
        if (s['engine'] is String) voice.setEngine(ttsEngineOf(s['engine'] as String));
        if (s['baseUrl'] is String) voice.setBaseUrl(s['baseUrl'] as String);
        if (s['model'] is String) voice.setModel(s['model'] as String);
        if (s['voice'] is String) voice.setVoice(s['voice'] as String);
        if (s['instructions'] is String) voice.setInstructions(s['instructions'] as String);
        if (s['speed'] is num) voice.setSpeed((s['speed'] as num).toDouble());
        if (s['authStyle'] is String) voice.setAuthStyle(authStyleOf(s['authStyle'] as String));
      } catch (_) {
        report.warnings.add('voice settings could not be restored');
      }
    }
  }

  void _visitArchiveAssetFields(Map<String, dynamic> doc, void Function(Map, String) visit) {
    final settings = doc['settings'];
    if (settings is Map) visit(settings, 'wallpaperPath');
    for (final c in (doc['chats'] as List? ?? const [])) {
      if (c is! Map) continue;
      visit(c, 'wallpaperPath');
      if (c['persona'] is Map) visit(c['persona'] as Map, 'avatarPath');
      for (final m in (c['msgs'] as List? ?? const [])) {
        if (m is Map && m['data'] is Map) {
          visit(m['data'] as Map, 'path');
          visit(m['data'] as Map, 'thumb');
        }
      }
    }
    for (final p in (doc['personas'] as List? ?? const [])) {
      if (p is Map) visit(p, 'avatarPath');
    }
    final stickers = doc['stickers'];
    if (stickers is Map) {
      for (final s in (stickers['items'] as List? ?? const [])) {
        if (s is Map && s['kind'] != 'emoji') {
          visit(s, 'value');
          visit(s, 'thumb');
        }
      }
    }
  }
}
