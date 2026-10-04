import 'dart:async';

import 'package:flutter/foundation.dart';

import 'android_proot_runtime.dart';
import 'environment_installer.dart';
import 'workspace_channel.dart';
import 'workspace_runtime.dart';

/// Owns the channel, the installer and the one runtime.
///
/// Assembled once at startup and handed to the pages. The alternative, building
/// a runtime per tool call, would re-probe proot on every shell call and every
/// one of those probes chmods two files.
class WorkspaceStack {
  WorkspaceStack({required this.channel, required this.installer, required this.dirs});

  final WorkspaceChannel channel;
  final EnvironmentInstaller installer;
  final EnvironmentDirs dirs;

  AndroidProotRuntime? _runtime;

  /// Null when proot is not present, which is the flutter test case and a build
  /// made before the native side existed.
  AndroidProotRuntime runtime() => _runtime ??= AndroidProotRuntime(channel, envDir: dirs.root, tmpDir: dirs.tmp);

  /// Registers the runtime and recovers an interrupted install.
  ///
  /// Ordered: recover before register. Recovery reads the marker on disk and
  /// decides whether anything is installed, and registering first would publish
  /// a status computed against a tree that recovery is about to replace.
  Future<void> start() async {
    await dirs.ensure();
    await installer.refresh();
    // An install or a removal changes whether the environment-backed tools can
    // run, and the tool table reads the provider rather than the installer, so
    // the provider is re-probed whenever the install lands in a phase where
    // runnability may have moved. Progress ticks are not terminal phases and do
    // not reach here.
    installer.states
        .where((s) =>
            s.phase == EnvPhase.ready ||
            s.phase == EnvPhase.notInstalled ||
            s.phase == EnvPhase.error)
        .listen((_) => unawaited(workspaceRuntimeProvider.refresh()));
  }
}

/// The process-wide runtime provider.
///
/// A singleton because the terminal, the workspace pages and the tool layer all
/// need the same runtime, and three instances means three probes and three sets
/// of PTY sessions that cannot see each other.
final WorkspaceRuntimeProvider workspaceRuntimeProvider = WorkspaceRuntimeProvider();

/// Builds the stack and publishes it. Called once from main.
Future<WorkspaceStack> bootstrapWorkspace() async {
  final channel = WorkspaceChannel();
  final env = await WorkspaceEnvironment.create(channel);
  final stack = WorkspaceStack(channel: channel, installer: EnvironmentInstaller(channel: channel, dirs: env.dirs), dirs: env.dirs);
  workspaceRuntimeProvider.register(stack.runtime());
  await stack.start();
  // The one probe that makes the shell tool exist. wsAvailable reads
  // lastStatus, and without this call it stays null for the whole process, so
  // the tool table never offers shell or view_image even on a device with a
  // fully installed environment. The terminal works regardless because it
  // probes the runtime directly.
  await workspaceRuntimeProvider.refresh();
  return stack;
}

/// Progress of an extraction, forwarded from the event channel to whoever is
/// watching an install.
///
/// A separate listenable rather than a field on the installer because the native
/// side pushes extract events whether or not an install is running, and the
/// workspace page wants the current value synchronously.
class ExtractProgress extends ChangeNotifier {
  int entries = 0;
  int bytes = 0;
  String currentEntry = '';

  void update(int entries, int bytes, String entry) {
    if (this.entries == entries && this.bytes == bytes && this.currentEntry == entry) return;
    this.entries = entries;
    this.bytes = bytes;
    this.currentEntry = entry;
    notifyListeners();
  }
}

final ExtractProgress extractProgress = ExtractProgress();

/// Wires the extract events onto [extractProgress]. One subscription for the
/// app: the event channel is broadcast and re-listening per page would deliver
/// each chunk to every page that was ever opened.
void watchExtractEvents(WorkspaceChannel channel) {
  channel.onExtract((entries, bytes, entry) => extractProgress.update(entries, bytes, entry));
}