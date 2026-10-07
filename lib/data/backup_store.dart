part of 'store.dart';

/// Reads and writes the whole account as one document.
///
/// This is the layer that knows about a [Store]. The format itself lives in
/// `backup.dart` and is pure, so what a file contains can be tested without a
/// database or a device, and what a restore does can be tested without a store.
///
/// A part rather than an extension because an extension cannot reach the store's
/// own fields: the ai config, the save debounce and notifyListeners are all
/// private, and every one of them is needed to finish a restore cleanly.
///
/// A part rather than a plain import because the extension only sees the store's
/// privates from inside the same library, the same trick store_human.dart uses.
extension BackupStore on Store {
  // ---------------------------------------------------------- auto backup

  void _loadAutoBackup() {
    final sp = _sp;
    autoBackup
      ..mode = sp.getString('autoBackup.mode') ?? 'change'
      ..intervalMin = sp.getInt('autoBackup.intervalMin') ?? 720
      ..windowStart = sp.getInt('autoBackup.windowStart') ?? 180
      ..windowEnd = sp.getInt('autoBackup.windowEnd') ?? 300
      ..lastAt = sp.getInt('autoBackup.lastAt') ?? 0
      ..lastHash = sp.getInt('autoBackup.lastHash') ?? 0;
  }

  /// Persists the policy; turning a mode on kicks an immediate write so the
  /// switch never sits on an empty promise.
  Future<void> setAutoBackup({String? mode, int? intervalMin, int? windowStart, int? windowEnd}) async {
    final ab = autoBackup;
    if (mode != null) ab.mode = mode;
    if (intervalMin != null) ab.intervalMin = intervalMin;
    if (windowStart != null) ab.windowStart = windowStart;
    if (windowEnd != null) ab.windowEnd = windowEnd;
    final sp = _sp;
    await sp.setString('autoBackup.mode', ab.mode);
    await sp.setInt('autoBackup.intervalMin', ab.intervalMin);
    await sp.setInt('autoBackup.windowStart', ab.windowStart);
    await sp.setInt('autoBackup.windowEnd', ab.windowEnd);
    if (ab.enabled) await backupNow();
    bump();
  }

  /// A cheap content fingerprint: ids, message counts and last message times
  /// catch new and edited messages without paying for a full export first.
  int _backupFingerprint() {
    var h = 17;
    for (final c in chats) {
      h = (h * 31 + c.id.hashCode) & 0x7fffffff;
      h = (h * 31 + c.msgs.length) & 0x7fffffff;
      h = (h * 31 + (c.msgs.isEmpty ? 0 : c.msgs.last.time)) & 0x7fffffff;
    }
    h = (h * 31 + personas.length) & 0x7fffffff;
    return h;
  }

  Future<void> _autoBackupTick() async {
    if (_backupRunning) return;
    final ab = autoBackup;
    final sink = _backupSink;
    if (!ab.enabled || sink == null) return;
    final now = DateTime.now();
    final fp = _backupFingerprint();
    final changed = _backupDirty || fp != ab.lastHash;
    if (!ab.shouldRun(now, dataChanged: changed)) return;
    _backupRunning = true;
    _backupDirty = false;
    try {
      final bytes = await exportBackupArchive();
      await sink.write(bytes);
      ab.noteSuccess(now, fp);
      await _sp.setInt('autoBackup.lastAt', ab.lastAt);
      await _sp.setInt('autoBackup.lastHash', ab.lastHash);
      bump();
      // the remote copy is best effort and runs after the local success is
      // recorded, so a dead server can never make a saved backup look failed
      unawaited(_uploadRemote(bytes));
      // the curated archive and the full snapshot share one schedule: same
      // policy, same overwrite rule, one dirty mark. the full zip gets its
      // own guard so a failure there never rewrites the archive's bookkeeping
      try {
        await _writeFullBackup();
      } catch (_) {}
    } catch (_) {
      // a failed backup must never surface as an app error; the next tick
      // retries, and the change mode keeps the dirty mark via the fingerprint
    } finally {
      _backupRunning = false;
    }
  }

  /// Forces a write immediately, whatever the schedule says.
  Future<void> backupNow() async {
    _backupDirty = true;
    autoBackup.lastAt = 0;
    await _autoBackupTick();
  }

  /// The backup an onboarding restore can offer. Null when none exists.
  Future<Uint8List?> readAutoBackup() async {
    final sink = _backupSink;
    if (sink == null) return null;
    try {
      final raw = await sink.read();
      if (raw == null || raw.isEmpty) return null;
      return raw is Uint8List ? raw : Uint8List.fromList(raw);
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds the whole data directory snapshot and overwrites the shared
  /// copy. Runs right after the archive write inside the same guard so the
  /// two artifacts can never disagree about which schedule they follow.
  Future<void> _writeFullBackup() async {
    final sink = _fullSink;
    if (sink == null) return;
    final bytes = await FullBackup.build();
    await sink.write(bytes);
  }

  /// The full zip backup a reinstall can offer. Null when none exists.
  Future<Uint8List?> readFullBackup() async {
    final sink = _fullSink;
    if (sink == null) return null;
    try {
      final raw = await sink.read();
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  /// Whether a full zip backup file exists at all, readable or not.
  Future<bool> hasFullBackupFile() async {
    final sink = _fullSink;
    if (sink == null) return false;
    try {
      return await sink.exists();
    } catch (_) {
      return false;
    }
  }

  /// Whether a backup file exists at all, even one this fresh install cannot
  /// read directly. Drives the manual-pick offer in onboarding.
  Future<bool> hasAutoBackupFile() async {
    final sink = _backupSink;
    if (sink == null) return false;
    try {
      return await sink.exists();
    } catch (_) {
      return false;
    }
  }

  /// Test seam: point the auto backup at a directory sink so a tick can be
  /// verified end to end without the MediaStore channel.
  @visibleForTesting
  set debugBackupSink(BackupSink? sink) => _backupSink = sink;

  /// Test seam for the full zip backup, same idea as [debugBackupSink].
  @visibleForTesting
  set debugFullBackupSink(FullBackupSink? sink) => _fullSink = sink;

  // ----------------------------------------------------------------- archive

  /// The files worth carrying: every avatar, every saved sticker and its
  /// thumbnail, and the wallpaper. Missing files are skipped rather than
  /// failing the export, because a path that already points at nothing should
  /// not cost the user the rest of the backup.
  Future<List<BackupAsset>> _collectAssets() async {
    final paths = <String>{};
    for (final c in chats) {
      if (c.persona.avatarPath.isNotEmpty) paths.add(c.persona.avatarPath);
    }
    for (final p in personas) {
      if (p.avatarPath.isNotEmpty) paths.add(p.avatarPath);
    }
    final h = human;
    if (h != null) {
      for (final s in h.stickers.items) {
        if (!s.isRemote && s.value.isNotEmpty) paths.add(s.value);
        if (s.thumb.isNotEmpty) paths.add(s.thumb);
      }
    }
    if (wallpaperPath.isNotEmpty) paths.add(wallpaperPath);

    final out = <BackupAsset>[];
    for (final path in paths) {
      try {
        final f = File(path);
        if (!await f.exists()) continue;
        out.add(BackupAsset(orig: path, data: await f.readAsBytes()));
      } catch (_) {
        // an unreadable file costs that picture, never the whole backup
      }
    }
    return out;
  }

  /// The archive a manual export and an automatic backup both write: the
  /// document plus every picture it names.
  Future<Uint8List> exportBackupArchive() async =>
      buildBackupZip(json: exportBackupString(), assets: await _collectAssets());

  /// Restores an archive, or an old plain-json backup.
  ///
  /// The assets are unpacked into app storage first, then every path in the
  /// document that pointed at one of them is rewritten to its new home before
  /// the document is applied. Doing it in that order is what makes avatars,
  /// stickers and the wallpaper come back on a device that never had the files.
  Future<BackupReport> importBackupArchive(List<int> bytes, {required bool overwrite}) async {
    if (!looksLikeZip(bytes)) {
      return importBackupString(utf8.decode(bytes, allowMalformed: true), overwrite: overwrite);
    }
    final archive = readBackupZip(bytes);
    final moved = await _restoreAssets(archive.assets);
    return importBackupString(_rewritePaths(archive.json, moved), overwrite: overwrite);
  }

  /// Writes every carried file into a fresh directory under app storage and
  /// returns a map from the exporting device's path to the new one.
  Future<Map<String, String>> _restoreAssets(List<BackupAssetFile> assets) async {
    final moved = <String, String>{};
    if (assets.isEmpty) return moved;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/restored_assets');
      if (!await dir.exists()) await dir.create(recursive: true);
      var n = 0;
      for (final a in assets) {
        try {
          final name = '${DateTime.now().microsecondsSinceEpoch}_${n++}_${_assetName(a.orig)}';
          final f = File('${dir.path}/$name');
          await f.writeAsBytes(a.data, flush: true);
          moved[a.orig] = f.path;
        } catch (_) {
          // one file that cannot be written costs that picture, not the restore
        }
      }
    } catch (_) {
      return moved;
    }
    return moved;
  }

  /// Rewrites every string equal to a moved path, anywhere in the document.
  /// Walking the decoded tree beats a text replace: a path could contain
  /// characters a regex would misread, and this only touches whole values.
  String _rewritePaths(String json, Map<String, String> moved) {
    if (moved.isEmpty) return json;
    Object? walk(Object? v) {
      if (v is String) return moved[v] ?? v;
      if (v is List) return [for (final e in v) walk(e)];
      if (v is Map) return {for (final e in v.entries) e.key: walk(e.value)};
      return v;
    }
    try {
      return jsonEncode(walk(jsonDecode(json)));
    } catch (_) {
      return json;
    }
  }

  String _assetName(String path) {
    final i = path.lastIndexOf('/');
    final raw = i < 0 ? path : path.substring(i + 1);
    final clean = raw.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return clean.isEmpty ? 'file' : clean;
  }

  // ------------------------------------------------------------------ remote

  void _loadRemoteBackup() {
    final raw = _sp.getString('backup.remote');
    if (raw == null || raw.isEmpty) return;
    try {
      remoteBackup = RemoteConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // a damaged blob reads as unset; never let it stop the app
    }
  }

  /// Persists a remote target. Kept out of the exported document on purpose:
  /// the archive is a thing people hand around, and this holds credentials.
  Future<void> setRemoteBackup(RemoteConfig config) async {
    remoteBackup = config;
    await _sp.setString('backup.remote', jsonEncode(config.toJson()));
    bump();
  }

  /// Probes the configured target. Never throws: the answer is the message.
  Future<RemoteResult> testRemoteBackup() async {
    final cfg = remoteBackup;
    if (!cfg.isConfigured) return const RemoteResult(false, 'Not configured.');
    try {
      return await cfg.build().test();
    } catch (e) {
      return RemoteResult(false, '$e');
    }
  }

  /// Uploads the current archive right now. Throws so the UI can report a
  /// failure the user just asked for.
  Future<void> backupToRemoteNow() async {
    final cfg = remoteBackup;
    if (!cfg.isConfigured) throw StateError('Remote backup is not configured.');
    final at = DateTime.now();
    await cfg.build().upload(await exportBackupArchive(), remoteBackupFileName(at));
    await _sp.setString('backup.remoteDate', _remoteDay(at));
  }

  /// The archives already on the remote, newest first. Only names this app
  /// understands are returned, so a folder shared with other files stays clean.
  Future<List<RemoteEntry>> listRemoteBackups() async {
    final cfg = remoteBackup;
    if (!cfg.isConfigured) return const [];
    final entries = await cfg.build().list();
    return (entries.where((e) => e.name.endsWith('.$autoBackupExt') || e.name.endsWith('.json')).toList()
      ..sort((a, b) => b.name.compareTo(a.name)));
  }

  /// Downloads one remote archive and restores it. [name] comes from
  /// [listRemoteBackups].
  Future<BackupReport> restoreFromRemote(String name, {required bool overwrite}) async {
    final cfg = remoteBackup;
    if (!cfg.isConfigured) throw StateError('Remote backup is not configured.');
    final bytes = await cfg.build().download(name);
    return importBackupArchive(bytes, overwrite: overwrite);
  }

  /// The automatic remote copy: at most once a day, named by that day.
  ///
  /// The local sink runs after every editing burst; the remote must not, or a
  /// few minutes of typing would push a dozen near-identical uploads. One dated
  /// file per day keeps the folder readable and the traffic bounded, and a run
  /// later the same day finds the marker set and does nothing.
  Future<void> _uploadRemote(List<int> bytes) async {
    final cfg = remoteBackup;
    if (!cfg.enabled || !cfg.isConfigured) return;
    final at = DateTime.now();
    final day = _remoteDay(at);
    if ((_sp.getString('backup.remoteDate') ?? '') == day) return;
    try {
      await cfg.build().upload(bytes is Uint8List ? bytes : Uint8List.fromList(bytes), remoteBackupFileName(at));
      await _sp.setString('backup.remoteDate', day);
      bump();
    } catch (_) {
      // remote is best effort; the local copy already succeeded, and a failure
      // leaves the date unset so the next tick tries again the same day
    }
  }

  static String _remoteDay(DateTime at) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${p(at.month)}-${p(at.day)}';
  }

  /// The document to hand the user. Carries the provider keys in `secrets`:
  /// a backup whose restore leaves every provider unconfigured is no backup.
  String exportBackupString() => buildBackup(
        chats: chats.map((c) => c.toJson()).toList(),
        personas: personas.map((p) => p.toJson()).toList(),
        stickers: human == null ? null : jsonDecode(human!.exportStickers()) as Map<String, dynamic>,
        memory: human == null ? null : jsonDecode(human!.exportMemory()) as Map<String, dynamic>,
        wallet: human?.wallet.toJson(),
        humanSettings: human?.settings.toJson(),
        tasks: human?.scheduler.toJson(),
        settings: exportSettings(),
        ai: _ai?.settings.toJson(),
        secrets: _ai?.apiKeys.isEmpty == false ? Map<String, dynamic>.of(_ai!.apiKeys) : null,
      );

  /// The preferences worth carrying to another phone.
  ///
  /// Not a dump of SharedPreferences: that would carry the API keys and the
  /// per chat compaction checkpoints, and a user who reads the file should not
  /// be holding credentials.
  Map<String, dynamic> exportSettings() => {
        'dark': dark,
        'textSize': textSize,
        'bubbleRadius': bubbleRadius,
        'haptics': haptics,
        'countMuted': countMuted,
        'showThinking': showThinking,
        'agentMode': agentMode,
        'agentMaxPass': agentMaxPass,
        'userBio': userBio,
        'locale': localeTag,
        'wallpaperPath': wallpaperPath,
        'wallpaperBlur': wallpaperBlur,
        'wallpaperBubbleGrad': wallpaperBubbleGrad,
        'wallpaperColor': wallpaperColor,
      };

  /// Applies a file.
  ///
  /// Every section is independent and every record is applied on its own, so one
  /// unreadable conversation cannot cost the rest of the backup. That is the
  /// failure this whole change exists to remove: the loader this replaces
  /// wrapped the entire chat list in one try and cleared it on any error.
  BackupReport importBackupString(String raw, {required bool overwrite}) {
    final doc = parseBackup(raw);
    final report = BackupReport();

    final picked = selectChats(doc, chats.map((c) => c.id), overwrite: overwrite);
    report.warnings.addAll(picked.skipped);
    for (final j in picked.take) {
      try {
        final c = Chat.fromJson(j);
        final at = chats.indexWhere((e) => e.id == c.id);
        if (at >= 0) {
          // the old one keeps its listener, the replacement needs its own or
          // later edits to it would never be saved
          _unlisten(chats[at]);
          chats[at] = c;
        } else {
          chats.add(c);
        }
        // createChat does the same, and a chat without it changes without ever
        // reaching storage
        _listen(c);
        report.chats++;
        report.messages += c.msgs.length;
      } catch (e) {
        report.warnings.add('chat ${j['id']}, could not be read');
      }
    }

    for (final j in doc.personas) {
      try {
        final p = UserPersona.fromJson(j);
        if (p.id.isEmpty) continue;
        final at = personas.indexWhere((e) => e.id == p.id);
        if (at >= 0 && !overwrite) continue;
        if (at >= 0) {
          personas[at] = p;
        } else {
          personas.add(p);
        }
        report.personas++;
      } catch (_) {
        report.warnings.add('a persona card, could not be read');
      }
    }

    // The sticker and memory sections are the existing envelopes verbatim, so
    // they go back through the existing importers and a section that is not
    // ours still fails the same way it always has.
    final h = human;
    if (h != null) {
      if (doc.stickers != null) {
        try {
          report.stickers = h.importStickers(jsonEncode(doc.stickers), overwrite: overwrite);
        } on FormatException catch (e) {
          report.warnings.add(e.message);
        }
      }
      if (doc.memory != null) {
        try {
          report.memories = h.importMemory(jsonEncode(doc.memory), overwrite: overwrite);
        } on FormatException catch (e) {
          report.warnings.add(e.message);
        }
      }
      // The wallet, the assistant settings and the scheduled messages are plain
      // preference blobs, so they go back through their own loaders. None of them
      // holds a credential; the API keys stay out of the document on purpose,
      // which is why a restored provider arrives without one.
      var humanTouched = false;
      if (doc.wallet != null) {
        try {
          h.wallet.loadJson(doc.wallet!);
          report.wallet = true;
          humanTouched = true;
        } catch (_) {
          report.warnings.add('the wallet, could not be read');
        }
      }
      if (doc.human != null) {
        try {
          h.settings = HumanSettings.fromJson(doc.human!);
          report.human = true;
          humanTouched = true;
        } catch (_) {
          report.warnings.add('the assistant settings, could not be read');
        }
      }
      if (doc.tasks != null) {
        try {
          h.scheduler.loadJson(doc.tasks!);
          report.tasks = doc.tasks!.length;
          humanTouched = true;
        } catch (_) {
          report.warnings.add('the scheduled messages, could not be read');
        }
      }
      if (humanTouched) h.changed();
    }

    report.settings = _applySettings(doc.settings);

    final ai = _ai;
    if (ai != null && doc.ai != null) {
      try {
        // providers and the chain come back together with the secrets below,
        // so a restored provider is working, not just present
        ai.update((_) => sanitizeAiSettings(doc.ai!));
        report.ai = true;
      } catch (_) {
        report.warnings.add('the model configuration, could not be read');
      }
    }
    final secrets = doc.secrets;
    if (secrets != null) {
      for (final e in secrets.entries) {
        final v = e.value;
        if (v is String && v.isNotEmpty) {
          ai?.saveApiKey(e.key, v);
          report.secrets++;
        }
      }
    }

    chatsChanged();
    return report;
  }

  int _applySettings(Map<String, dynamic> s) {
    var n = 0;
    void put<T>(String key, T value, void Function(T) apply) {
      final v = s[key];
      if (v is T) {
        apply(v);
        n++;
      }
    }

    put('dark', dark, setDark);
    put('textSize', textSize, setTextSize);
    put('bubbleRadius', bubbleRadius, setRadius);
    put('haptics', haptics, setHaptics);
    put('countMuted', countMuted, setCountMuted);
    put('showThinking', showThinking, setShowThinking);
    put('agentMode', agentMode, setAgentMode);
    put('agentMaxPass', agentMaxPass, setAgentMaxPass);
    put('userBio', userBio, (v) => setProfile(bio: v));
    put('locale', localeTag ?? '', (v) => setLocale(v.isEmpty ? null : v));
    put('wallpaperPath', wallpaperPath, setWallpaper);
    put('wallpaperBlur', wallpaperBlur, setWallpaperBlur);
    put('wallpaperBubbleGrad', wallpaperBubbleGrad, setWallpaperBubbleGrad);
    // deliberately not setWallpaperColor: that reads as an int and also pushes
    // into the palette, which the caller does once at the end instead
    final wc = s['wallpaperColor'];
    if (wc is int) {
      setWallpaperColor(wc == 0 ? null : wc);
      n++;
    }
    return n;
  }
}