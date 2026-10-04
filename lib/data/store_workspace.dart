part of 'store.dart';

// The workspace half of a reply. It is a part rather than an extension because
// the tool table needs the run table, to hang the trace row off, and an
// extension cannot reach a private field.
//
// Three states, and the difference matters:
//   off            no workspace tool exists and the prompt says nothing
//   on, unbound    same as off, because a tool pointed at no directory would
//                  have to be pointed at the app's documents dir, which is the
//                  one thing the path layer exists to prevent
//   on, bound      the six file tools and a <workspace> block
//
// The tools are gated on WorkspaceStore.toolsEnabled rather than on either reply
// switch, so a user who wants file tools does not also have to turn on agent
// mode and give up the humanize layer.

extension StoreWorkspace on Store {
  /// Null when this chat has no workspace to work in. Null rather than empty so
  /// both call sites can ask before concatenating instead of one of them
  /// forgetting to.
  Workspace? wsFor(Chat c) {
    final id = c.ws.workspaceId;
    return id == null ? null : workspace.byId(id);
  }

  /// True when the tools would actually be offered, which is not the same as
  /// the switch being on. The settings row uses it to explain an inert toggle.
  bool wsActive(Chat c) => workspace.toolsEnabled && wsFor(c) != null;

  Future<WsContext?> wsContext(Chat c, {Workspace? w}) async {
    final ws = w ?? wsFor(c);
    if (!workspace.toolsEnabled || ws == null) return null;
    final ctx = WsContext(
      paths: await workspace.pathsFor(ws, c.id, cwd: c.ws.cwd),
      binding: c.ws,
      disabledTools: ws.disabledTools,
      confirmWrite: workspace.confirmWrites ? (w) => _wsConfirm(c, w) : null,
    );
    // a cancel that lands mid write should stop the write, not the next tool
    ctx.checkCancelled = () {
      final run = _runs[c.id];
      if (run != null && run.cancelled) throw HostFileException('cancelled');
    };
    return ctx;
  }

  /// Local tools the workspace contributes. Empty when it contributes none, so
  /// the caller appends unconditionally.
  ///
  /// [run] may be null, which is how the settings pane reads the table to show
  /// the descriptions. A tool called that way has nowhere to put its metadata,
  /// which is the correct outcome for a table nobody is going to run.
  /// The workspace tool table. Both halves of the reply go through here, so the
  /// availability rule is stated once: a tool the device cannot run must not be
  /// in the table at all, because a tool error the model retries is worse than a
  /// tool that was never offered.
  Future<List<HTool>> wsTools(Chat c, [_Run? run]) async {
    final ctx = await wsContext(c);
    if (ctx == null) return const [];
    return [
      for (final name in WorkspaceTools.toolNames)
        if (ctx.allows(name) && wsAvailable(name))
          HTool(name, _wsDescription(name), WorkspaceTools.schemaFor(name), (a) => _wsRun(c, run, ctx, name, a), required: _wsRequired(name)),
    ];
  }

  /// The six file tools always can. shell and view_image need an installed Linux
  /// environment.
  bool wsAvailable(String name) {
    if (!WorkspaceTools.needsEnvironment(name)) return true;
    final status = workspaceRuntimeProvider.lastStatus;
    return status != null && status.ready;
  }

  /// Runs one tool and puts its UI-only metadata on the trace row.
  ///
  /// The result text goes to the model and stops there. The diff, the file list
  /// and the byte counts go into the row, are persisted with the chat, and are
  /// never read back into a prompt.
  Future<String> _wsRun(Chat c, _Run? run, WsContext ctx, String name, Map<String, dynamic> a) async {
    WsResult? out;
    try {
      out = name == 'shell' ? await WorkspaceTools.shell(ctx, a, (r) => _runShell(ctx, r)) : await WorkspaceTools.call(ctx, name, a);
    } catch (e) {
      out = WsResult('Error: $e', WorkspaceToolMeta(tool: name, status: 'error', code: 'exception'));
    }
    if (run != null) wsMeta(c, run, out.meta);
    wsTouched(c);
    return out.text;
  }

  /// Runs one command in the installed environment.
  ///
  /// The output is capped and spilled to a file past the cap, because a build
  /// that prints ten thousand lines would otherwise land in the transcript and
  /// blow the context on its own.
  Future<ShellOutcome> _runShell(WsContext ctx, ShellRequest request) async {
    final stack = workspaceStack;
    final runtime = stack?.runtime();
    if (runtime == null) throw HostFileException('no workspace runtime is registered');
    final status = await runtime.status();
    if (!status.ready) throw HostFileException(status.reason.isEmpty ? 'the Linux environment is not ready' : status.reason);
    // resolves the guest path and refuses one that escapes, so a shell command
    // cannot be aimed at a directory the file tools would not open
    final cwd = ctx.paths.resolve(request.cwd).modelPath;

    final id = 'ws-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final stream = runtime.execStream(
      CommandRequest(
        runId: id,
        command: request.command,
        rootfsDir: runtime.rootfsDir,
        tmpDir: runtime.tmpDir,
        cwd: cwd,
        timeout: request.timeout,
        env: WorkspaceTools.guestEnv,
        mounts: runtime.zoneMounts(),
      ),
    );

    final out = StringBuffer();
    final err = StringBuffer();
    final sub = stream.output.listen((o) {
      final text = utf8.decode(o.bytes, allowMalformed: true);
      (o.isStderr ? err : out).write(text);
      if (out.length + err.length > _shellOutputCap) {
        // the cap is enforced by cancelling rather than by truncating, so the
        // model gets a real failure rather than output that stops mid line
        unawaited(runtime.cancel(id));
      }
    });

    try {
      await for (final e in stream.events) {
        if (e is CommandExited) {
          await sub.cancel();
          final spill = await _spill(ctx, id, out.toString() + err.toString());
          return ShellOutcome(
            exitCode: e.exitCode,
            duration: e.duration,
            stdout: out.toString(),
            stderr: err.toString(),
            timedOut: e.timedOut,
            cancelled: e.cancelled,
            outputFile: spill,
          );
        }
      }
    } finally {
      await sub.cancel();
    }
    // the stream closed without an exit event, which means the native side
    // refused the command rather than running it
    throw HostFileException('the command did not start');
  }

  static const int _shellOutputCap = 64 * 1024;

  /// Writes output that went past the cap into the session outputs zone, where
  /// the model can read_file it and the user can open it.
  Future<String?> _spill(WsContext ctx, String id, String text) async {
    if (text.length <= _shellOutputCap) return null;
    final file = File(p.join(ctx.paths.chatHostRoot, 'outputs', '$id.txt'));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
    return ctx.paths.toModelPath(file.path);
  }

  /// Merges [meta] into the row this run is writing into. Writing through
  /// Msg.data rather than replacing it keeps the row's own fields.
  void wsMeta(Chat c, _Run run, WorkspaceToolMeta meta) {
    final row = run.row;
    // no row means agent mode is off, so the tool ran with nowhere to report to
    if (row == null) return;
    row.data['ws'] = meta.toJson();
    // Msg.onChange is not wired to anything, so the row growing a diff does not
    // repaint on its own. Going through the chat is what the list listens to.
    c.touch();
    _scheduleSave();
  }

  /// Records the first real tool use so unbinding can ask first. Not called for
  /// a tool that was switched off or refused, which is the difference between
  /// "tried" and "used".
  void wsTouched(Chat c) {
    if (c.ws.toolsUsed || !c.ws.isBound) return;
    c.ws.toolsUsed = true;
    c.touch();
    _scheduleSave();
    workspace.touchLastUsed(c.ws.workspaceId!);
  }

  Future<bool?> _wsConfirm(Chat c, WsPendingWrite write) async {
    final handler = wsReviewHandler;
    // nobody is looking at the app: a proactive reply must still be able to
    // write, or the scheduler could never do anything the user asked it to
    if (handler == null) return true;
    return handler(write, c);
  }

  /// The `<workspace>` block for the system prompt, or null.
  Future<String?> wsPrompt(Chat c) async {
    final ctx = await wsContext(c);
    final w = wsFor(c);
    if (ctx == null || w == null) return null;
    return WorkspaceTools.promptFragment(ctx, name: w.name, isAvailable: wsAvailable);
  }

  /// One line for the chat header and the workspace picker: where the files are
  /// and how many tools are on, so a user who cannot tell why the model cannot
  /// see a file can work it out from the row.
  String wsSummary(Chat c) {
    final w = wsFor(c);
    if (w == null) return L10n.current.wsNoWorkspace;
    if (!workspace.toolsEnabled) return '${w.name} · ${L10n.current.wsToolsOff}';
    final on = WorkspaceTools.toolNames.where((t) => !w.disabledTools.contains(t)).length;
    return '${w.name} · $on/${WorkspaceTools.toolNames.length}';
  }

  // ------------------------------------------------------------- tool table

  String _wsDescription(String name) => switch (name) {
        'read_file' => 'Read a file from the workspace as numbered lines. Pass offset to continue a read that was cut short. Images come back as a link you can show.',
        'write_file' => 'Create a file or replace its whole contents. The user sees the diff before it lands. Prefer edit_file when the file already exists.',
        'edit_file' => 'Replace one piece of text in a file. Matching tolerates whitespace drift but old_string must be unique unless replace_all is set. Read the file first.',
        'list_dir' => 'List a directory in the workspace. Directories end with /, files show their size.',
        'glob' => 'Find files by name pattern, for example **/*.dart. Matches paths relative to the search directory.',
        'grep' => 'Search file contents with a regex across the workspace. An invalid regex is searched for literally.',
        _ => '',
      };

  List<String> _wsRequired(String name) => switch (name) {
        'read_file' => const ['path'],
        'write_file' => const ['path', 'content'],
        'edit_file' => const ['path', 'old_string', 'new_string'],
        'list_dir' => const [],
        'glob' => const ['pattern'],
        'grep' => const ['pattern'],
        _ => const [],
      };

  /// The tools this chat contributed locally, so the prompt's "you have N tools"
  /// line stays true without a constant to keep in step by hand. Counts only what
  /// is actually offered, which is why it consults [wsAvailable] rather than the
  /// raw name list.
  int wsLocalToolCount(Chat c) {
    final w = wsFor(c);
    if (w == null || !workspace.toolsEnabled) return 0;
    return WorkspaceTools.toolNames.where((t) => !w.disabledTools.contains(t) && wsAvailable(t)).length;
  }
}