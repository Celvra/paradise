import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'human_models.dart';
import 'mcp_client.dart';
import 'memory.dart';
import 'scheduler.dart';
import 'sticker_lib.dart';
import 'wallet.dart';

/// Owner of everything the humanize layer persists. The engine itself lives in
/// store_human.dart because it needs the store internals.
class HumanHub extends ChangeNotifier {
  HumanHub._(this._sp);
  final SharedPreferences _sp;

  HumanSettings settings = HumanSettings();
  final MemoryBank memory = MemoryBank();
  final StickerLib stickers = StickerLib();
  final Scheduler scheduler = Scheduler();
  final Wallet wallet = Wallet();
  final McpHub mcp = McpHub();

  /// guards the heartbeat against overlapping runs
  bool ticking = false;

  /// Rolling logs for the debug panel
  final List<String> toolLog = [];
  final List<String> gateLog = [];

  /// what was cut off when the user interrupted, per chat, consumed by the
  /// next generation so the model can decide whether to say it again
  final Map<String, String> interruptNotes = {};

  /// Set by the UI. Asked when a tool is on "ask", returns the user's answer.
  Future<bool> Function(String tool, Map<String, dynamic> args)? askHandler;

  /// Called for each assistant message that lands while the chat is not on
  /// screen, and when one is recalled. The app wires notifications to this.
  void Function(String chatId, String msgId, String title, String body)? onNotify;
  void Function(String msgId)? onCancelNotify;

  List<McpServerConfig> get mcpServers => [for (final m in settings.mcp) McpServerConfig.fromJson(m)];

  static Future<HumanHub> load(SharedPreferences sp) async {
    final h = HumanHub._(sp);
    try {
      final s = sp.getString('h_settings');
      if (s != null) h.settings = HumanSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      final m = sp.getString('h_memory');
      if (m != null) h.memory.importJson(jsonDecode(m) as List, overwrite: true);
      final st = sp.getString('h_stickers');
      if (st != null) h.stickers.importJson(jsonDecode(st) as List, overwrite: true);
      final t = sp.getString('h_tasks');
      if (t != null) h.scheduler.loadJson(jsonDecode(t) as List);
      final w = sp.getString('h_wallet');
      if (w != null) {
        h.wallet.loadJson(jsonDecode(w) as Map<String, dynamic>);
      } else {
        h.wallet.balance = 1000;
      }
    } catch (_) {
      // a damaged blob must never keep the app from starting
    }
    if (h.settings.deviceId.isEmpty) h.settings.deviceId = 'dev_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    return h;
  }

  void save() {
    _sp.setString('h_settings', jsonEncode(settings.toJson()));
    _sp.setString('h_memory', jsonEncode(memory.toJson()));
    _sp.setString('h_stickers', jsonEncode(stickers.toJson()));
    _sp.setString('h_tasks', jsonEncode(scheduler.toJson()));
    _sp.setString('h_wallet', jsonEncode(wallet.toJson()));
  }

  /// Persist and repaint.
  void changed() {
    save();
    notifyListeners();
  }

  void logTool(String line) {
    toolLog.add('${DateTime.now().toIso8601String().substring(11, 19)} $line');
    if (toolLog.length > 120) toolLog.removeAt(0);
  }

  void logGate(String line) {
    gateLog.add('${DateTime.now().toIso8601String().substring(11, 19)} $line');
    if (gateLog.length > 120) gateLog.removeAt(0);
  }

  ToolPerm permFor(String tool, {required bool external}) {
    final raw = settings.perms[tool];
    if (raw != null) return permOf(raw);
    return external ? ToolPerm.ask : ToolPerm.allow;
  }

  void setPerm(String tool, ToolPerm p) {
    settings.perms[tool] = p.name;
    changed();
  }

  // ----------------------------------------------------------------- backup

  /// stickers, memory and settings leave as one readable JSON document
  String exportStickers() => const JsonEncoder.withIndent('  ').convert({'kind': 'lib3.stickers', 'version': 1, 'items': stickers.toJson()});
  String exportMemory() => const JsonEncoder.withIndent('  ').convert({'kind': 'lib3.memory', 'version': 1, 'items': memory.toJson()});

  /// Returns how many entries were read, throws FormatException for a foreign file.
  int importStickers(String raw, {required bool overwrite}) {
    final j = jsonDecode(raw);
    if (j is! Map || j['kind'] != 'lib3.stickers') throw const FormatException('not a sticker export');
    final list = j['items'] as List;
    stickers.importJson(list, overwrite: overwrite);
    changed();
    return list.length;
  }

  int importMemory(String raw, {required bool overwrite}) {
    final j = jsonDecode(raw);
    if (j is! Map || j['kind'] != 'lib3.memory') throw const FormatException('not a memory export');
    final list = j['items'] as List;
    memory.importJson(list, overwrite: overwrite);
    changed();
    return list.length;
  }
}
